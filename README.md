# tech-challenge-infra-database

Infraestrutura como código do banco de dados gerenciado — Tech Challenge SOAT, Fase 3.

## Propósito

Provisiona, via Terraform, o banco de dados gerenciado que substitui o PostgreSQL que rodava como deployment dentro do cluster na Fase 2.

Responsabilidades deste repositório:

- Instância gerenciada em subnet privada, sem acesso público
- Alta disponibilidade e backup automatizado
- Credenciais no gerenciador de segredos da nuvem
- Criptografia em repouso e em trânsito
- Parametrização por ambiente (`dev`, `hom`, `prod`)

A rede e o cluster ficam em [tech-challenge-infra-k8s](https://github.com/tech-challenge-grupo-160/tech-challenge-infra-k8s). O schema e as migrations pertencem à [aplicação principal](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica).

## Status

> ⚠️ **Scaffold.** O provedor de nuvem ainda não foi decidido — depende da RFC [#56](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/56). A justificativa formal da escolha do banco é a issue [#76](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/76).

## Tecnologias

| Item | Definição |
|---|---|
| IaC | Terraform |
| Banco | PostgreSQL (versão a confirmar na justificativa formal) |
| Nuvem | A definir — RFC [#56](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/56) |
| State | Backend remoto com lock ([issue #57](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/57)) |

## Estrutura prevista

```text
.
├── main.tf                    # Instância gerenciada, subnet group, parameter group
├── variables.tf
├── outputs.tf                 # Endpoint e ARN do segredo (sem expor credencial)
├── versions.tf
└── inventories/
    ├── dev/terraform.tfvars
    ├── hom/terraform.tfvars
    └── prod/terraform.tfvars
```

Mesma convenção de `inventories/` já usada no repositório de infraestrutura Kubernetes.

## Execução

```bash
terraform init
terraform plan -var-file=inventories/dev/terraform.tfvars
```

O `apply` roda pelo pipeline, não manualmente — ver seção abaixo.

## Deploy

Pipeline em GitHub Actions ([issue #51](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/51)):

| Evento | Ação |
|---|---|
| Pull Request | `fmt`, `validate` e `plan` publicado como comentário no PR |
| Merge em `homolog` | `apply` no ambiente de homologação |
| Merge em `main` | `apply` no ambiente de produção |

Autenticação na nuvem por OIDC ([issue #54](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/54)) — sem credencial estática em secrets.

## Segurança

Nenhuma credencial neste repositório. A senha do banco é gerada pelo Terraform e gravada direto no gerenciador de segredos; os `outputs` expõem apenas o ARN do segredo, nunca o valor.

## Repositórios do projeto

| Repositório | Conteúdo |
|---|---|
| [tech-challenge-oficina-mecanica](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica) | API .NET e documentação |
| [tech-challenge-lambda-auth](https://github.com/tech-challenge-grupo-160/tech-challenge-lambda-auth) | Function serverless de autenticação |
| [tech-challenge-infra-k8s](https://github.com/tech-challenge-grupo-160/tech-challenge-infra-k8s) | Terraform do cluster Kubernetes |
| [tech-challenge-infra-database](https://github.com/tech-challenge-grupo-160/tech-challenge-infra-database) | Este repositório |

## Contribuição

Branch `main` protegida — sem commits diretos. Toda mudança entra por Pull Request com pelo menos uma aprovação.
