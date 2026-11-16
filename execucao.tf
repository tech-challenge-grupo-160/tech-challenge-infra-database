# PostgreSQL proprio da Execucao (F4-12, ADR-0006).
#
# Segunda instancia neste repositorio, e nao no infra/ do repositorio da
# Execucao como dizia a issue: aquela pasta e aplicada pelo workflow da
# mensageria a todo push, e um RDS la passaria a depender da rede de pe e a
# criar banco pago a cada merge. Aqui ja existem o state remoto da rede, o
# subnet group, o SG do banco, o pipeline e a ordem certa no sobe-tudo e no
# derruba-tudo. Decisao registrada na issue #143 em 09/11.
#
# Reaproveita do banco do OS Service so o que e infraestrutura comum: subnet
# group, parameter group (TLS obrigatorio) e o sg_banco. Instancia, banco,
# usuario e segredo sao proprios - o OS Service nao recebe esta credencial.
#
# Diferente do banco do OS (Multi-AZ desde a issue #61), este e Single-AZ em
# dev e hom e Multi-AZ so em prod, como pede a F4-12.

resource "random_password" "execucao" {
  length  = 32
  special = false # mesmo motivo do banco do OS: escaping na connection string

  keepers = {
    ambiente = var.ambiente
  }
}

resource "aws_secretsmanager_secret" "execucao" {
  name        = "${var.project}/${var.ambiente}/execucao/banco"
  description = "Credencial e connection string do PostgreSQL da Execucao. Lida so pela pipeline da Execucao."

  # Mesmo motivo do segredo do OS: o lab e recriado a cada sessao.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "execucao" {
  secret_id = aws_secretsmanager_secret.execucao.id

  secret_string = jsonencode({
    host     = aws_db_instance.execucao.address
    port     = aws_db_instance.execucao.port
    database = var.execucao_nome_banco
    username = var.execucao_usuario
    password = random_password.execucao.result
    connectionString = join(";", [
      "Host=${aws_db_instance.execucao.address}",
      "Port=${aws_db_instance.execucao.port}",
      "Database=${var.execucao_nome_banco}",
      "Username=${var.execucao_usuario}",
      "Password=${random_password.execucao.result}",
      "SSL Mode=Require",
      "Trust Server Certificate=true"
    ])
  })
}

resource "aws_db_instance" "execucao" {
  identifier     = "${local.nome}-execucao"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.execucao_nome_banco
  username = var.execucao_usuario
  password = random_password.execucao.result

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  # Sempre nas subnets privadas e so com o sg_banco: o acesso_externo_dev
  # existiu para a carga de schema do OS Service na Fase 3 e nao se aplica
  # aqui - as migrations da Execucao rodam no startup do pod.
  db_subnet_group_name   = aws_db_subnet_group.principal.name
  vpc_security_group_ids = [local.sg_banco]
  parameter_group_name   = aws_db_parameter_group.principal.name
  publicly_accessible    = false

  multi_az = var.execucao_multi_az

  backup_retention_period = var.backup_retention_period
  backup_window           = "06:00-07:00"
  maintenance_window      = "Mon:07:30-Mon:08:30"

  skip_final_snapshot = true
  deletion_protection = false

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = { Name = "${local.nome}-execucao", Service = "execucao" }
}
