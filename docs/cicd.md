# TC3-09 — CI/CD da infraestrutura

## Fluxo e ambientes

| Evento | Operação | Ambiente |
| --- | --- | --- |
| Push em qualquer branch | fmt, init sem backend, validate e testes com AWS simulada | Sem acesso AWS |
| PR interno aberto/atualizado para develop | Validação e plan | homologacao |
| Merge de PR em develop | Validação, novo plan do commit merged e apply do plano salvo | homologacao |
| PR interno aberto/atualizado para main | Validação e plan | producao |
| Merge de PR em main | Validação, novo plan do commit merged e apply do plano salvo | producao |
| PR fechado sem merge | Nenhum deploy | — |
| PR de fork aberto ou execução do Dependabot | Validação sem credenciais | — |

O evento de deploy é `pull_request_target: closed` com `merged == true`. Isso
permite que PRs vindos de fork façam deploy somente depois do merge, usando o
workflow e os secrets do repositório base. Push direto não faz apply. Promova
mudanças por PR para develop e depois por PR de develop para main. Crie a
branch develop a partir de main na preparação inicial.

O job `terraform` depende do sucesso de `validate`. O plano do PR aparece nos
logs e não é reaproveitado após o merge: um novo `deployment.tfplan` é gerado
para o commit integrado e aplicado no mesmo runner. Se a branch já tiver um
commit mais recente, o apply antigo falha sem alterar recursos. O merge mais
recente é responsável pelo deploy.

| Configuração | Homologação | Produção |
| --- | --- | --- |
| Branch | develop | main |
| GitHub Environment | homologacao | producao |
| Variável Terraform environment | staging | prod |
| Arquivo | environments/homologacao/environment.tfvars.json | environments/producao/environment.tfvars.json |
| VPC | 10.30.0.0/16 | 10.40.0.0/16 |
| RDS | tech-challenge-staging-postgres | tech-challenge-prod-postgres |
| Disponibilidade | Single-AZ | Multi-AZ |
| Backup | 7 dias | 14 dias |
| Chave S3 | tech-challenge-infra-db/homologacao/terraform.tfstate | tech-challenge-infra-db/producao/terraform.tfstate |

Os ambientes podem usar contas e buckets distintos. No laboratório, podem
compartilhar a conta temporária 213284176265 e o bucket, mantendo chaves,
nomes e redes separados. As aplicações devem usar os outputs do ambiente
correspondente. Multi-AZ cria capacidade adicional cobrada na AWS.

## 1. Preparar o bucket de state

Com AWS CLI instalada e credenciais válidas, execute uma vez no PowerShell.
O exemplo usa us-east-1; o nome do bucket deve ser globalmente único.

```powershell
$stateBucket = "tech-challenge-tfstate-213284176265-SEU_SUFIXO"
$awsRegion = "us-east-1"
aws sts get-caller-identity
aws s3api create-bucket --bucket $stateBucket --region $awsRegion
aws s3api put-bucket-versioning --bucket $stateBucket --versioning-configuration Status=Enabled --region $awsRegion
aws s3api put-public-access-block --bucket $stateBucket --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true --region $awsRegion
```

Substitua SEU_SUFIXO por letras minúsculas/números. Para regiões diferentes de
us-east-1, o create-bucket também exige LocationConstraint da região. O backend
envia objetos com criptografia SSE-S3 (`encrypt = true`) e usa o objeto `.tflock`
para locking (`use_lockfile = true`), disponível no Terraform >= 1.10.
Não é necessário DynamoDB. [Backend S3 oficial](https://developer.hashicorp.com/terraform/language/backend/s3).

O bucket não é criado pela pipeline: precisa existir antes do primeiro init.
Não remova esse bucket ao remover o RDS; ele guarda o histórico de state.

## 2. Configurar GitHub Environments

Em Settings → Environments, crie exatamente `homologacao` e `producao`.
Em cada um, configure estas **variables**:

| Nome | Valor |
| --- | --- |
| AWS_ACCOUNT_ID | Conta de 12 dígitos desse ambiente; laboratório: 213284176265 |
| AWS_REGION | us-east-1; esse também é o fallback da pipeline |
| TF_STATE_BUCKET | Nome do bucket preparado para o ambiente |
| AWS_ROLE_ARN | ARN da role OIDC; deixe ausente se usar secrets temporários |

A ação AWS, o backend e o provider verificam a conta esperada. Bucket e conta
são obrigatórios; a pipeline informa uma mensagem específica se faltarem.
Arquivos tfvars versionados não devem conter chaves AWS nem tokens.

## 3. Autenticação AWS

### OIDC

No IAM da conta do ambiente, configure o identity provider de tipo OpenID
Connect com URL `https://token.actions.githubusercontent.com` e audience
`sts.amazonaws.com`. Reutilize o provider se ele já existir. Crie uma role
para cada ambiente e configure AWS_ROLE_ARN nas variables do ambiente.

Trust policy de exemplo para homologação na conta do laboratório:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::213284176265:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:Leandro149/tech-challenge-infra-db:environment:homologacao"
      }
    }
  }]
}
```

Para produção, use a conta correspondente e `environment:producao` no sub.
A pipeline concede `id-token: write` apenas ao job Terraform que acessa AWS.
OIDC cria credenciais de sessão a cada execução, sem secrets AWS permanentes.
[Guia GitHub/AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws).

### Credenciais temporárias do laboratório

Se o laboratório não permitir criar roles OIDC, deixe AWS_ROLE_ARN ausente
e cadastre estes **secrets em cada environment**:

- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_SESSION_TOKEN

O token deve vir da mesma sessão das duas chaves. Credenciais iniciadas por
ASIA exigem esse token. Quando expirarem, atualize os três secrets antes do
próximo plan/apply. A pipeline não usa as credenciais salvas no computador.
Nunca copie valores para YAML, tfvars, logs ou commits.
[Uso de credenciais temporárias](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_use-resources.html).

### Permissões

A role OIDC ou a sessão de laboratório precisa das permissões de gestão dos
recursos Terraform: VPC, subnets, route tables, Security Groups e VPC endpoints;
RDS DB instance, DB subnet group e parameter group; CloudWatch Logs; criação,
versionamento, leitura, tags e exclusão da policy IAM de acesso ao secret;
e permissões de Secrets Manager/KMS exigidas pelo RDS para senha gerenciada.
Na primeira criação de RDS, a conta também pode precisar criar sua service-linked
role. A credencial usada na preparação do bucket precisa criar e configurar S3.

Para o backend de homologação, acrescente esta policy, substituindo BUCKET_REAL:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::BUCKET_REAL"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::BUCKET_REAL/tech-challenge-infra-db/homologacao/terraform.tfstate"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::BUCKET_REAL/tech-challenge-infra-db/homologacao/terraform.tfstate.tflock"
    }
  ]
}
```

Na role de produção, troque homologacao por producao e use seu bucket. Plan
também precisa criar/excluir o objeto de lock. Restrinja as permissões de
infraestrutura aos recursos desse ambiente conforme a política da conta.

## 4. Branches e proteção

Envie os arquivos da pipeline para main e crie/envie develop. Restrinja push
direto nessas branches e exija PR com o check `validate` aprovado. Assim toda
mudança de infraestrutura percorre o plano e o evento de merge.

Os mesmos GitHub Environments são usados para plan e apply. Se configurar
required reviewers no environment, ambos os jobs aguardarão essa aprovação;
sem reviewers, o apply é automático após merge. Caso restrinja deployment
branches, permita a branch de destino e as refs de PR `refs/pull/*/merge`
usadas no plan. [Proteções de ambientes](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).

Operações do mesmo ambiente compartilham um grupo concurrency com
cancel-in-progress=false; um apply ativo não é cancelado por novo PR. O lock
S3 também serializa operações com ferramentas externas. GitHub pode substituir
execuções pendentes por uma mais recente; examine a execução do último merge.
Para repetir um deploy que falhou por credenciais/permissões, corrija a
configuração e use Re-run jobs na execução do PR merged ainda atual.

## 5. State existente e execução local

O backend S3 substitui o backend local. Se já houver state local com recursos,
faça backup e inicialize com `terraform init -migrate-state` mais os argumentos
backend-config do ambiente correto, aceitando a migração após revisar a conta
e o destino. Não use reconfigure para abandonar um state com recursos.

Os comandos para criar/remover recursos com o mesmo backend e configurações
da CI estão no [README](../README.md). A validação com mocks continua usando
`terraform init -backend=false` e não precisa de bucket nem credenciais.

## Situação desta entrega

Pipeline e ambientes implementados e verificados localmente. A sessão AWS
temporária foi completada e sts get-caller-identity confirmou a conta
213284176265. O bucket `tech-challenge-infra-db-tfstate-213284176265` foi criado
em us-east-1 com versionamento e bloqueio de acesso público. Use esse nome em
TF_STATE_BUCKET para o laboratório; não é necessário recriar o bucket.

O backend local foi inicializado para homologação e um plan real foi gerado:
28 recursos para criar, zero alterações e zero exclusões. Nenhum apply foi
executado e o RDS ainda não foi criado.

Continuam pendentes as variables/secrets dos GitHub Environments. O acesso
GitHub local recebeu HTTP 403 ao consultar essas definições; sua configuração
deve ser feita com as permissões correspondentes no repositório. Cadastre a
sessão completa nos secrets dos ambientes, incluindo AWS_SESSION_TOKEN, ou use
OIDC. O apply continua sendo executado após merge pela pipeline.
