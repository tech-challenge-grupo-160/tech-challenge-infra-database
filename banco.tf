# PostgreSQL gerenciado (issue #61 / F3-27).
#
# A instancia fica nas subnets privadas da VPC criada pelo infra-k8s, sem
# acesso publico. Quem alcanca 5432 e apenas quem esta no sg_nodes ou no
# sg_lambda - as regras estao no security-groups.tf daquele repositorio.

resource "aws_db_subnet_group" "principal" {
  name        = local.nome
  description = "Subnets privadas do PostgreSQL gerenciado"
  subnet_ids  = local.subnets_privadas

  tags = { Name = local.nome }
}

# ------------------------------------------------------- credencial master

resource "random_password" "master" {
  length  = 32
  special = false # o Npgsql aceita, mas caracteres especiais na connection
  # string exigem escaping e ja custaram tempo de time demais.

  keepers = {
    ambiente = var.ambiente
  }
}

resource "aws_secretsmanager_secret" "credencial" {
  name        = "${var.project}/${var.ambiente}/banco"
  description = "Credencial master do PostgreSQL gerenciado e dados de conexao."

  # O ambiente do lab e destruido ao fim de cada sessao. Com a janela padrao
  # de 30 dias o nome ficaria reservado e o proximo apply falharia.
  recovery_window_in_days = 0
}

# Guarda o conjunto completo, nao so a senha: quem consome monta a connection
# string sem precisar de outra fonte. O endpoint entra depois que a instancia
# existe, por isso o depends_on implicito via aws_db_instance.
resource "aws_secretsmanager_secret_version" "credencial" {
  secret_id = aws_secretsmanager_secret.credencial.id

  secret_string = jsonencode({
    host     = aws_db_instance.principal.address
    port     = aws_db_instance.principal.port
    database = var.nome_banco
    username = var.usuario_master
    password = random_password.master.result
    # SSL Mode=Require porque o parameter group forca rds.force_ssl = 1.
    connectionString = join(";", [
      "Host=${aws_db_instance.principal.address}",
      "Port=${aws_db_instance.principal.port}",
      "Database=${var.nome_banco}",
      "Username=${var.usuario_master}",
      "Password=${random_password.master.result}",
      "SSL Mode=Require",
      "Trust Server Certificate=true"
    ])
  })
}

# --------------------------------------------- criptografia em transito

resource "aws_db_parameter_group" "principal" {
  name        = local.nome
  family      = "postgres${var.engine_version}"
  description = "Forca TLS nas conexoes do PostgreSQL"

  # Sem isto o banco aceita conexao em texto claro. E o que atende ao criterio
  # de criptografia em transito da issue #61.
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------- instancia

resource "aws_db_instance" "principal" {
  identifier     = local.nome
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.nome_banco
  username = var.usuario_master
  password = random_password.master.result

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"

  # Criptografia em repouso com a chave gerenciada pela AWS. O Learner Lab nao
  # permite criar chave propria no KMS.
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.principal.name
  vpc_security_group_ids = [local.sg_banco]
  parameter_group_name   = aws_db_parameter_group.principal.name

  # Sem acesso publico. Combinado com as subnets privadas - que nao tem rota
  # para a internet - o banco so e alcancavel de dentro da VPC.
  publicly_accessible = false

  multi_az = var.multi_az

  backup_retention_period = var.backup_retention_period
  backup_window           = "06:00-07:00" # madrugada no horario de Brasilia
  maintenance_window      = "Mon:07:30-Mon:08:30"

  # O ambiente do lab e recriado a cada sessao: snapshot final so atrapalharia
  # o destroy e deixaria custo para tras. Em producao de verdade seria false.
  skip_final_snapshot = true
  deletion_protection = false

  # Sem isto, qualquer apply que mude a versao menor derruba a instancia.
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = { Name = local.nome }
}
