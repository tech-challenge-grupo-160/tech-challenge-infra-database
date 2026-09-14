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

Ninguém pela internet. A instância fica em subnet privada, sem rota default, e
o security group só aceita `5432` de dois lugares:

- `sg_nodes` — os pods da API no cluster
- `sg_lambda` — a Lambda de autenticação, **quando anexada à VPC**

> ⚠️ A Lambda hoje roda fora da VPC. Anexá-la exige o endpoint de interface do
> Secrets Manager, senão ela perde o acesso ao segredo do JWT no cold start.

### A credencial

Gerada pelo Terraform e guardada em `tc-grupo160/<ambiente>/banco`, no Secrets
Manager. Nunca é versionada e nunca aparece em output.

O secret guarda o conjunto completo — host, porta, banco, usuário, senha e uma
`connectionString` pronta, já com `SSL Mode=Require`. Quem consome lê de lá em
runtime, do mesmo jeito que a Lambda já faz com a chave do JWT.

### Aplicar

**Actions → Terraform CI → Run workflow**, escolhendo o ambiente. O apply
também roda ao mergear em `homolog` (aplica `hom`) e em `main` (aplica `prod`).

> A criação leva de 10 a 15 minutos com Multi-AZ. O `terraform apply` fica
> aguardando a instância ficar disponível.

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
