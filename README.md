# tech-challenge-infra-database

Infraestrutura como código dos bancos relacionais gerenciados — Tech Challenge SOAT, Fases 3 e 4.

## Propósito

Provisiona, via Terraform, os dois PostgreSQL no Amazon RDS:

| Instância | Dono | Disponibilidade | Arquivo |
|---|---|---|---|
| `tc-grupo160-<ambiente>` | OS Service | Multi-AZ nos três ambientes | [`banco.tf`](banco.tf) |
| `tc-grupo160-<ambiente>-execucao` | Execução (F4-12) | Single-AZ em `dev` e `hom`, Multi-AZ em `prod` | [`execucao.tf`](execucao.tf) |

Um banco por serviço, pela ADR de banco por serviço (F4-04). O Billing usa
DynamoDB, que não fica aqui (F4-13).

Responsabilidades deste repositório:

- Instâncias gerenciadas em subnet privada, sem acesso público
- Backup automatizado e alta disponibilidade onde ela é avaliada
- Uma credencial por banco no Secrets Manager
- Criptografia em repouso e em trânsito
- Parametrização por ambiente (`dev`, `hom`, `prod`)

A rede e o cluster ficam em [tech-challenge-infra-k8s](https://github.com/tech-challenge-grupo-160/tech-challenge-infra-k8s). O schema e as migrations pertencem a cada serviço: o do OS à [aplicação principal](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica), o da Execução ao [repositório dela](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica-execucao).

## Status

As duas instâncias sobem e descem com o ambiente, pelos scripts do repositório
principal. O ciclo completo foi validado em `dev` em 09/11/2026.

> **Subir e derrubar o ambiente inteiro** é com os scripts do repositório
> principal — ver o
> [roteiro rápido](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/blob/develop/docs/CICLO-DE-VIDA.md#roteiro-rápido).
> O banco é a etapa 4 do `sobe-tudo.sh` e o passo 3 do `derruba-tudo.sh`.

## Tecnologias

| Item | Definição |
|---|---|
| IaC | Terraform |
| Banco | PostgreSQL 16 no Amazon RDS |
| Nuvem | AWS, região `us-east-1` — [RFC-0001](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/blob/develop/docs/rfcs/0001-escolha-da-nuvem.md) |
| State | S3 `tc-grupo160-tfstate-<id-da-conta>` com lock na tabela `tc-grupo160-tflock` |

## Estrutura

```text
.
├── banco.tf                   # RDS do OS Service, subnet group, parameter group e credencial
├── execucao.tf                # RDS da Execucao e credencial, reaproveitando subnet group e parameter group
├── data.tf                    # state remoto da rede (infra-k8s)
├── variables.tf
├── outputs.tf                 # endpoints e ARNs dos segredos (sem expor credencial)
├── versions.tf
└── inventories/
    ├── dev/terraform.tfvars
    ├── hom/terraform.tfvars
    └── prod/terraform.tfvars  # execucao_multi_az = true
```

Mesma convenção de `inventories/` já usada no repositório de infraestrutura Kubernetes.

## Execução

```bash
terraform init
terraform plan -var-file=inventories/dev/terraform.tfvars
```

O `apply` roda pelo pipeline ou pelo `sobe-tudo.sh`, não manualmente — ver
seção abaixo.

## Deploy

Pipeline em GitHub Actions ([issue #51](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/51)):

| Evento | Ação |
|---|---|
| Pull Request | `fmt`, `validate` e `plan` dos três ambientes |
| Merge em `develop` | `apply` em `dev` |
| Merge em `homolog` | `apply` no ambiente de homologação |
| Merge em `main` | `apply` no ambiente de produção |

A autenticação na AWS usa as credenciais temporárias do Learner Lab, guardadas
nos secrets do repositório e renovadas a cada sessão pelo `renova-secrets.sh`
do repositório principal. O lab não permite criar o provedor OIDC.

> **Com o ambiente derrubado, o plan de `dev` e `hom` falha em todo PR.** O state
> da rede continua no bucket, mas vazio, e o banco não acha os outputs. Não é
> problema da mudança. Para mergear nesse estado sem disparar um apply que vai
> falhar, pause o workflow (`gh workflow disable terraform-ci.yml`), mergeie e
> reative.

## Segurança

Nenhuma credencial neste repositório. A senha do banco é gerada pelo Terraform e gravada direto no gerenciador de segredos; os `outputs` expõem apenas o ARN do segredo, nunca o valor.

## Repositórios do projeto

| Repositório | Conteúdo |
|---|---|
| [tech-challenge-oficina-mecanica](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica) | API .NET e documentação |
| [tech-challenge-lambda-auth](https://github.com/tech-challenge-grupo-160/tech-challenge-lambda-auth) | Function serverless de autenticação |
| [tech-challenge-infra-k8s](https://github.com/tech-challenge-grupo-160/tech-challenge-infra-k8s) | Terraform do cluster Kubernetes |
| [tech-challenge-infra-database](https://github.com/tech-challenge-grupo-160/tech-challenge-infra-database) | Este repositório |
| [tech-challenge-oficina-mecanica-billing](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica-billing) | Billing Service (orçamento e pagamento) |
| [tech-challenge-oficina-mecanica-execucao](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica-execucao) | Execução Service (diagnóstico, estoque e reparo) |

## Contribuição

Branch `main` protegida — sem commits diretos. Toda mudança entra por Pull Request com pelo menos uma aprovação.

## Banco de dados

PostgreSQL gerenciado no Amazon RDS, provisionado pelo Terraform na raiz deste
repositório ([`banco.tf`](banco.tf)). Issue
[#61](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/61).

| Item | Valor |
|---|---|
| Engine | PostgreSQL 16 |
| Classe | `db.t3.micro` |
| Alta disponibilidade | Multi-AZ |
| Backup | automático, 7 dias de retenção |
| Criptografia em repouso | sim, chave gerenciada pela AWS |
| Criptografia em trânsito | `rds.force_ssl = 1` no parameter group |
| Acesso público | não |

### A rede vem do outro repositório

As subnets privadas e o security group do banco são criados no
[tech-challenge-infra-k8s](https://github.com/tech-challenge-grupo-160/tech-challenge-infra-k8s)
e lidos aqui pelo state remoto. **Aplicar a rede é pré-requisito** — sem o
`<ambiente>/rede.tfstate` no bucket, o plan falha ao ler os outputs.

O nome do bucket é montado a partir do id da conta em runtime, não recebido por
variável: ele contém o número da conta e este repositório é público.

### Quem alcança o banco

Ninguém pela internet. As duas instâncias ficam em subnet privada, sem rota
default, e compartilham o security group do banco, que só aceita `5432` de dois
lugares:

- `sg_nodes` — os pods no cluster
- `sg_lambda` — a Lambda de autenticação, que roda dentro da VPC e lê o segredo
  do JWT pelo endpoint de interface do Secrets Manager

O que separa um banco do outro é a credencial: cada serviço só recebe a do seu.

### A credencial

Gerada pelo Terraform, uma por instância, no Secrets Manager:

| Segredo | Quem recebe |
|---|---|
| `tc-grupo160/<ambiente>/banco` | OS Service e a Lambda de autenticação |
| `tc-grupo160/<ambiente>/execucao/banco` | só a Execução, pelo deploy dela |

Nunca são versionadas e nunca aparecem em output.

O secret guarda o conjunto completo — host, porta, banco, usuário, senha e uma
`connectionString` pronta, já com `SSL Mode=Require`. Quem consome lê de lá em
runtime, do mesmo jeito que a Lambda já faz com a chave do JWT.

### Aplicar

**Actions → Terraform CI → Run workflow**, escolhendo o ambiente. O apply
também roda ao mergear em `develop` (aplica `dev`), em `homolog` (aplica `hom`)
e em `main` (aplica `prod`). No ciclo completo, quem aplica é o `sobe-tudo.sh`,
na etapa 4.

> A criação leva de 10 a 15 minutos com Multi-AZ. As duas instâncias nascem em
> paralelo, no mesmo apply, e o `terraform apply` fica aguardando as duas ficarem
> disponíveis.

### Acesso externo temporário (só `dev`)

O schema é criado pelo `MigrateAndSeedAsync` no startup da API, que só sobe no
cluster ([#60](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/60)).
Com o banco privado não há de onde rodar as migrations enquanto o cluster não
existir, e a [#62](https://github.com/tech-challenge-grupo-160/tech-challenge-oficina-mecanica/issues/62)
fica bloqueada.

Para destravar, `acesso_externo_dev` expõe a instância restrita a CIDRs
específicos:

```hcl
acesso_externo_dev   = true
cidrs_acesso_externo = ["SEU.IP.AQUI/32"]
```

**Não é economia de custo.** O endpoint do Secrets Manager continua necessário,
porque a Lambda segue dentro da VPC. O que isso compra é tempo — carregar o
schema hoje em vez de esperar o cluster.

Três proteções, todas verificadas:

| Tentativa | Resultado |
|---|---|
| Ligar em `hom` ou `prod` | recusado — o banco fica privado onde é avaliado |
| Ligar sem informar CIDR | recusado |
| Informar `0.0.0.0/0` | recusado — seria um PostgreSQL aberto para a internet |

> ⚠️ Ligar **move a instância para as subnets públicas**, o que a substitui — e
> substituir apaga os dados. Carregue o schema, desligue o flag e aplique de
> novo antes de popular qualquer coisa que importe.

O output `acesso_externo` diz se está ligado. Deve ser `false` em `hom` e `prod`
sempre, e em `dev` fora da janela de carga.
