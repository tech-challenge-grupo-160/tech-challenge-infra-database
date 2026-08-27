output "endpoint" {
  description = "Endereco do banco. Alcancavel apenas de dentro da VPC."
  value       = aws_db_instance.principal.address
}

output "porta" {
  description = "Porta do PostgreSQL."
  value       = aws_db_instance.principal.port
}

output "nome_banco" {
  description = "Nome do banco criado na instancia."
  value       = var.nome_banco
}

# O nome, nunca o valor. Quem consome le do Secrets Manager em runtime, como
# a Lambda ja faz com a chave do JWT.
output "secret_credencial" {
  description = "Nome do secret com a credencial e a connection string prontas."
  value       = aws_secretsmanager_secret.credencial.name
}

output "multi_az" {
  description = "Se a instancia esta em duas zonas de disponibilidade."
  value       = aws_db_instance.principal.multi_az
}
