variable "region" {
  description = "Regiao AWS. O AWS Academy Learner Lab so permite us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefixo dos recursos."
  type        = string
  default     = "tc-grupo160"
}

variable "ambiente" {
  description = "Ambiente logico (dev, hom, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "hom", "prod"], var.ambiente)
    error_message = "ambiente deve ser dev, hom ou prod."
  }
}

variable "engine_version" {
  description = "Versao do PostgreSQL. Igual a do docker-compose e do Testcontainers da aplicacao."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "Classe da instancia. O Learner Lab limita as classes disponiveis."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento inicial em GB."
  type        = number
  default     = 20
}

variable "multi_az" {
  description = <<-EOT
    Alta disponibilidade em duas zonas. Exigido pela issue #61.
    Contraria a RFC-0001, que decidiu Single-AZ por custo - a decisao foi
    revista em 2026-08-27: a diferenca e de ~US$ 0,43/dia numa db.t3.micro e
    o ambiente e destruido ao fim de cada sessao do lab.
  EOT
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Dias de retencao do backup automatico. Zero desliga o backup."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period > 0
    error_message = "A issue #61 exige backup automatizado: a retencao precisa ser maior que zero."
  }
}

variable "nome_banco" {
  description = "Nome do banco criado na instancia."
  type        = string
  default     = "oficina_mecanica"
}

variable "usuario_master" {
  description = "Usuario master. A senha e gerada pelo Terraform e guardada no Secrets Manager."
  type        = string
  default     = "oficina_admin"
}
