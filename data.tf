data "aws_caller_identity" "atual" {}

# A rede vive no repositorio tech-challenge-infra-k8s e e lida pelo state
# remoto, nao recriada aqui. Os outputs consumidos - subnets_privadas e
# sg_banco - existem la desde a issue #58, e o sg_banco ja carrega o
# comentario "Consumido pelo repositorio infra-database".
#
# O nome do bucket e montado, nao recebido por variavel: ele contem o id da
# conta e este repositorio e publico. A convencao vem do bootstrap do
# infra-k8s, que cria "<project>-tfstate-<conta>".
#
# O acoplamento e por state, nao por codigo: aplicar a rede antes e
# pre-requisito, e o erro de nao aplicar e explicito.
data "terraform_remote_state" "rede" {
  backend = "s3"

  config = {
    bucket = "${var.project}-tfstate-${data.aws_caller_identity.atual.account_id}"
    key    = "${var.ambiente}/rede.tfstate"
    region = var.region
  }
}

locals {
  nome = "${var.project}-${var.ambiente}"

  subnets_privadas = data.terraform_remote_state.rede.outputs.subnets_privadas
  sg_banco         = data.terraform_remote_state.rede.outputs.sg_banco
}
