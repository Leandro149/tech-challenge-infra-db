# TC3-05 / TC3-09 — PostgreSQL e CI/CD Terraform

Projeto de infraestrutura para o Tech Challenge da pós-graduação. Provisiona
Amazon RDS PostgreSQL em rede privada, com backups, parâmetros e acesso
controlado para aplicações AWS Lambda e Amazon EKS.

A pipeline executa `fmt`, `validate` e testes em pushes, gera `plan` em PRs
internos e executa `apply` após merge. `develop` usa homologação e `main` usa
produção, com configurações e state separados. A preparação do GitHub e da AWS
está no [guia de CI/CD](docs/cicd.md).

## Atendimento à atividade

| Requisito | Implementação |
| --- | --- |
| Provisionar RDS PostgreSQL | PostgreSQL 16 por padrão, instância `db.t4g.micro`, gp3 criptografado e autoscaling de 20 até 100 GiB. |
| VPC e subnets | VPC com DNS, duas subnets de banco e duas de aplicação em duas zonas; também permite reutilizar VPC/subnets existentes. |
| Security Groups | RDS recebe TCP 5432 somente dos SGs autorizados de Lambda/EKS. Sem ingresso por CIDR público. |
| Backup e parâmetros | Backups automáticos de 7 dias, snapshot final, proteção contra exclusão, TLS obrigatório e logs no CloudWatch. |
| Acesso Lambda/EKS | SGs de clientes, outputs de integração, endpoint privado do Secrets Manager e policy IAM limitada ao secret do banco. |

## Arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `versions.tf` | Versões do Terraform/provider, região e tags. |
| `variables.tf`, `locals.tf` | Configuração, validações e nomes dos recursos. |
| `network.tf` | VPC, subnets, rotas privadas, subnet group e endpoint de secrets. |
| `security.tf` | SGs e regras de entrada/saída. |
| `database.tf` | RDS, parâmetros, logs e policy de leitura do secret. |
| `outputs.tf` | IDs, endpoint e ARNs para integração. |
| `terraform.tfvars.example` | Exemplo para criar uma rede nova. |
| `examples/existing-vpc.tfvars.example` | Exemplo para usar a rede do EKS/Lambda. |
| `tests/infrastructure.tftest.hcl` | Testes locais com AWS simulada. |
| `backend.tf`, `environments/*/backend.hcl` | Backend S3 e chaves de state por ambiente. |
| `environments/*/environment.tfvars.json` | Configurações de homologação e produção. |
| `tests/environments/environment.tftest.hcl` | Testes das configurações reais dos ambientes. |
| `.github/workflows/terraform.yml` | Validação, plan em PR e apply após merge. |
| `docs/cicd.md` | Configuração de CI/CD, backend e autenticação AWS. |

## Pré-requisitos

- Terraform >= 1.10 e < 2.0; a CI usa 1.16.2 e locking nativo do S3.
- AWS CLI e uma conta com credenciais configuradas.
- Permissões para gerenciar VPC/subnets/SGs/endpoints, RDS, logs e a policy IAM,
  além das permissões de Secrets Manager/KMS necessárias para criação do RDS.
- Bucket S3 de state preparado conforme o [guia de CI/CD](docs/cicd.md).
- Git, se desejar versionar e enviar a entrega.

Instale o Terraform pelo [guia oficial](https://developer.hashicorp.com/terraform/install)
e configure o acesso AWS. Para credenciais de laboratório, use `aws configure`;
se a instituição usa IAM Identity Center, use `aws configure sso` e
`aws sso login --profile NOME_DO_PERFIL`, definindo `AWS_PROFILE` na sessão.
Não coloque chaves AWS nos arquivos Terraform.

## Criar a infraestrutura

Os comandos abaixo funcionam no PowerShell, dentro deste diretório.

Escolha `homologacao` ou `producao` e edite o `environment.tfvars.json`
correspondente. Homologação usa Single-AZ; produção usa Multi-AZ e 14 dias de
backup. Confirme a região, o bucket previamente criado e um
`final_snapshot_identifier` único para cada ciclo do laboratório.

```powershell
$deploymentEnvironment = "homologacao"
$stateBucket = "NOME_DO_BUCKET_DE_STATE"
$awsRegion = "us-east-1"
$expectedAccountId = "213284176265"

$actualAccountId = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0 -or $actualAccountId -ne $expectedAccountId) {
  throw "Verifique as credenciais e a conta AWS antes de inicializar."
}
terraform init -reconfigure "-backend-config=environments/$deploymentEnvironment/backend.hcl" "-backend-config=bucket=$stateBucket" "-backend-config=region=$awsRegion"
terraform fmt -check -recursive
terraform validate
terraform plan "-var-file=environments/$deploymentEnvironment/environment.tfvars.json" "-var=aws_region=$awsRegion" "-var=aws_account_id=$expectedAccountId" "-out=deployment.tfplan"
terraform apply deployment.tfplan
terraform output
```

Revise o plano antes de aplicar. O `apply` cria recursos cobrados na AWS e a
instância RDS pode levar vários minutos para ficar disponível. A classe e a
versão devem estar disponíveis na região e na conta; para consultar:

```powershell
aws rds describe-db-engine-versions --engine postgres --region us-east-1 --query "DBEngineVersions[].EngineVersion" --output table
```

Uma versão major como `16` deixa o RDS escolher uma minor disponível. Para
fixar a versão inicial, informe a versão minor real retornada pela AWS.
Atualizações minor automáticas ficam habilitadas; upgrades major não são
automáticos neste projeto.

## Reutilizar a VPC do EKS/Lambda

Se as aplicações já existem, use a VPC delas para manter a conectividade privada:

Use `examples/existing-vpc.tfvars.example` como referência e adicione os campos
`existing_*` ao `environment.tfvars.json` do ambiente escolhido. Mantenha o
`environment` como `staging` ou `prod`, conforme o arquivo.

Substitua os IDs fictícios pelos reais. Informe subnets privadas de banco em
duas zonas diferentes e subnets privadas de aplicação. Quando criar o endpoint
de secrets, informe apenas uma subnet de aplicação por zona e habilite DNS
support/hostnames na VPC existente. Se ela já possui endpoint Secrets Manager
com DNS privado, use `create_secrets_manager_endpoint = false` para não duplicá-lo.

O Terraform verifica a VPC e a atribuição automática de IP público das subnets,
além das zonas do banco. Também verifique as tabelas de rotas: desabilitar
atribuição de IP público, isoladamente, não comprova que uma subnet é privada.
As rotas e subnets existentes não são alteradas por este projeto.

No mapa `existing_client_security_group_ids`, informe o SG efetivamente
associado à Lambda e às interfaces de rede dos nodes/pods do EKS. O projeto
adiciona ingresso no RDS e no endpoint de secrets para esses SGs. Os SGs
existentes devem permitir saída TCP 5432 para o SG do RDS e HTTPS 443 para o
endpoint de secrets; ajuste essa saída no projeto que gerencia esses SGs.

## Integrar a Lambda

No projeto da função, use os outputs deste Terraform:

1. Configure a Lambda na mesma `vpc_id`, usando `application_subnet_ids`.
2. Associe `lambda_security_group_id` à configuração VPC da função.
3. Garanta permissões de gerenciamento de ENIs na execution role, por exemplo
   com a policy AWS `AWSLambdaVPCAccessExecutionRole`.
4. Associe `database_secret_read_policy_arn` à execution role autorizada.
5. Configure a aplicação com `database_host`, `database_port`, `database_name`
   e `database_master_secret_arn`. Recupere a senha pelo SDK em tempo de execução
   e use TLS com verificação do certificado.

Exemplo de bloco para inserir no recurso `aws_lambda_function` da aplicação,
passando os outputs como variáveis no projeto consumidor:

```hcl
vpc_config {
  subnet_ids         = var.database_application_subnet_ids
  security_group_ids = [var.database_lambda_security_group_id]
}
```

As permissões de ENI e o SG autorizam a rede. A policy de secrets autoriza a
leitura da credencial; a autenticação PostgreSQL usa usuário/senha. Se a função
precisar acessar outros serviços, adicione os SGs/egress e endpoints apropriados
no projeto da aplicação.

## Integrar o EKS

Para um cluster existente, o caminho mais simples é reutilizar sua VPC e informar
o SG dos nodes no exemplo de VPC existente. Autorizar o SG dos nodes permite
acesso aos workloads que usam suas interfaces; para restringir a pods específicos,
configure **Security Groups for Pods** no cluster e associe o output
`eks_security_group_id` aos pods selecionados por `SecurityGroupPolicy`.
Essa configuração exige os pré-requisitos do Amazon VPC CNI e nodes compatíveis.

Não basta associar o SG somente ao control plane: o SG autorizado precisa
corresponder às interfaces que originam a conexão. Os SGs de acesso ao banco
criados aqui são adicionais; mantenha também as regras necessárias de DNS e
comunicação interna do cluster.

Associe a policy `database_secret_read_policy_arn` à role da aplicação via
EKS Pod Identity ou IRSA. Configure o workload com os outputs de conexão e
recupere a credencial em tempo de execução.

Este repositório fornece a infraestrutura do banco. A Lambda, o cluster EKS,
nodes, ServiceAccounts e suas associações IAM/SG são configurados nos projetos
de aplicação. A VPC nova possui somente rotas locais e o endpoint de secrets;
para subir EKS nessa rede, o projeto do cluster deve fornecer NAT ou os demais
endpoints necessários para APIs AWS e imagens de containers.

## Senha, TLS e usuários de aplicação

O RDS gera e administra a senha no Secrets Manager. O Terraform recebe o ARN
do secret, sem ler a senha nem armazená-la como variável. O endpoint privado
permite que aplicações da VPC façam a leitura por HTTPS sem NAT. Se sua criação
for desativada, forneça outro endpoint ou saída HTTPS e regras de SG adequadas.

Para a demonstração acadêmica, a policy criada permite acesso ao secret do
administrador. Em uma aplicação real, crie usuários PostgreSQL com privilégios
restritos e secrets próprios por aplicação, por meio de migrations ou de uma
etapa administrativa. O projeto não habilita autenticação IAM do PostgreSQL.

`rds.force_ssl = 1` exige TLS. Use `sslmode=verify-full` e o certificado raiz
AWS RDS na conexão; o bundle está disponível no
[guia de certificados RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html).
Após alterar um parâmetro com `pending-reboot`, reinicie a instância em uma
janela apropriada para efetivar a alteração.

## Backups, logs e demonstração

- Backups automáticos: 7 dias por padrão, configuráveis de 1 a 35 dias.
- Janela de backup: **03:00–04:00 UTC**; manutenção: **domingo 05:00–06:00 UTC**.
- Snapshot final exigido por padrão, com nome definido pelo aluno.
- Backups automáticos retidos após exclusão pelo prazo restante da retenção.
- Logs de conexão/desconexão e consultas acima de 1 segundo; exportação
  `postgresql` para CloudWatch com retenção de 14 dias.

Para comprovar a entrega, registre o RDS privado, subnet group com duas zonas,
regras de SG, retenção de backup e parameter group no console. Dentro de uma
Lambda ou pod autorizado, execute uma conexão TLS e consulte:

```sql
SELECT version(), current_database();
SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid();
SHOW rds.force_ssl;
```

O campo `ssl` deve ser `true`. Uma máquina fora da VPC não conecta diretamente
ao banco privado. Para administração, use uma máquina ou túnel autorizado dentro
da rede, mantendo as regras específicas. Backups automáticos permitem restauração
point-in-time dentro da retenção; a restauração cria outra instância RDS, que deve
ser posteriormente incorporada ao Terraform e aos endpoints das aplicações.

## Validação sem criar recursos AWS

```powershell
terraform init -backend=false -input=false
terraform fmt -check -recursive
terraform validate
terraform test -no-color
terraform test -no-color -test-directory=tests/environments "-var-file=environments/homologacao/environment.tfvars.json"
terraform test -no-color -test-directory=tests/environments "-var-file=environments/producao/environment.tfvars.json"
```

Os testes usam `mock_provider "aws"`: simulam recursos e consultas, verificando
segurança padrão, integração de VPC existente e rejeição de configurações
inválidas. Não precisam de credenciais AWS e não provisionam recursos, inclusive
nos testes com `command = apply`. O primeiro `init` precisa de internet para
baixar o provider. A CI executa as mesmas verificações.

O lock inclui checksums para Windows (`windows_amd64`) e para o runner Linux
da CI (`linux_amd64`). Ao atualizar o provider, gere e versione os checksums
das duas plataformas antes de enviar a alteração:

```powershell
terraform providers lock -platform=windows_amd64 -platform=linux_amd64
```

A CI usa `terraform init -backend=false -input=false -lockfile=readonly`.
Se faltar o checksum `h1` do Linux, o `init` pode baixar o provider sem salvar
esse checksum, e o `validate` falha com `does not match any of the checksums`.
O comando acima prepara o lock para ambas as plataformas, conforme a
[documentação oficial](https://developer.hashicorp.com/terraform/cli/commands/providers/lock).

Os mocks validam a configuração. Disponibilidade regional, quotas, permissões
IAM e conectividade real precisam ser verificados na conta no `plan`/`apply`
e na demonstração de conexão.

## State e custos

O backend é S3, com criptografia e lock nativo; homologação e produção possuem
chaves distintas. O bucket deve existir e ter versionamento e bloqueio de
acesso público. `terraform.tfvars`, planos e state estão ignorados no Git;
`.terraform.lock.hcl` deve ser versionado. Inicialize o backend do ambiente
correto antes de administrar ou excluir seus recursos. Para migrar state
local existente, use o procedimento do [guia de CI/CD](docs/cicd.md).

Há cobrança pelo RDS, armazenamento, Secrets Manager, endpoints Interface por
zona, logs e backups/snapshots conforme uso e plano da conta. Single-AZ reduz
o custo, mas não oferece standby. Consulte os preços AWS da região escolhida;
esta configuração não pressupõe gratuidade. Snapshots finais e backups retidos
podem continuar gerando custo após excluir a instância.

## Remover o laboratório

Primeiro edite o `environment.tfvars.json` do ambiente escolhido, definindo
`deletion_protection = false`. Inicialize o mesmo backend usado no deploy.
Confirme que o nome do snapshot final ainda não existe. Depois execute:

```powershell
terraform plan "-var-file=environments/$deploymentEnvironment/environment.tfvars.json" "-var=aws_region=$awsRegion" "-var=aws_account_id=$expectedAccountId" "-out=cleanup-preparation.tfplan"
terraform apply cleanup-preparation.tfplan
terraform plan -destroy "-var-file=environments/$deploymentEnvironment/environment.tfvars.json" "-var=aws_region=$awsRegion" "-var=aws_account_id=$expectedAccountId" "-out=destroy.tfplan"
terraform apply destroy.tfplan
```

O RDS gera snapshot final porque `skip_final_snapshot = false`. Em laboratório
descartável, você pode definir `skip_final_snapshot = true` antes da preparação,
aceitando a perda dessa cópia. Desassocie a policy IAM e os SGs deste projeto
das aplicações antes de destruir, para evitar dependências que bloqueiem a
exclusão. No modo existente, a VPC/subnets/SGs informados são preservados.
Revise no console os snapshots finais e backups retidos e remova-os quando
não precisar mais dos dados.

## Referências oficiais

- [RDS em VPC e requisitos de subnets](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [Recurso Terraform aws_db_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)
- [Versões PostgreSQL no RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.DBVersions.html)
- [TLS no PostgreSQL RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html)
- [Lambda com acesso à VPC](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html)
- [Security Groups for Pods no EKS](https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html)
- [Mocks de providers no Terraform](https://developer.hashicorp.com/terraform/language/tests/mocking)
