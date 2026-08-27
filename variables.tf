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

variable "acesso_externo_dev" {
  description = <<-EOT
    Expoe o banco fora da VPC, restrito aos CIDRs de cidrs_acesso_externo.

    Existe por um motivo especifico: o schema e criado pelo MigrateAndSeedAsync
    no startup da API, que so sobe no cluster (issue #60). Com o banco privado
    nao ha de onde rodar as migrations enquanto o cluster nao existir, e a
    issue #62 fica bloqueada.

    Nao e otimizacao de custo. O endpoint do Secrets Manager continua
    necessario, porque a Lambda segue dentro da VPC.

    Ligar move a instancia para as subnets publicas, o que **substitui** a
    instancia. Desligue assim que o schema estiver carregado.
  EOT
  type        = bool
  default     = false

  validation {
    condition     = !var.acesso_externo_dev || var.ambiente == "dev"
    error_message = "acesso_externo_dev so pode ser ligado em dev. Em hom e prod o banco fica privado, como exige a issue #61."
  }
}

variable "cidrs_acesso_externo" {
  description = "CIDRs autorizados quando acesso_externo_dev estiver ligado. Use o IP de quem vai rodar as migrations, com /32."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.acesso_externo_dev || length(var.cidrs_acesso_externo) > 0
    error_message = "Com acesso_externo_dev ligado, informe ao menos um CIDR em cidrs_acesso_externo."
  }

  validation {
    condition     = !contains(var.cidrs_acesso_externo, "0.0.0.0/0")
    error_message = "0.0.0.0/0 nao e aceito: seria um PostgreSQL aberto para a internet, protegido apenas pela senha. Use o IP de quem precisa, com /32."
  }
}
