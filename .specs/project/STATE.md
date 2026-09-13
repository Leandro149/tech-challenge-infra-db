# Estado do projeto

## Concluído

- TC3-05: Terraform de VPC/subnets, RDS PostgreSQL, SGs, backups e parâmetros.
- Rede nova ou existente; endpoint privado de secrets opcional.
- Senha gerenciada pelo RDS; Terraform exporta somente o ARN e cria policy
  de leitura restrita para associação pelas aplicações.
- README em português, exemplos e CI de validação sem credenciais AWS.
- Commits separados de implementação, testes e documentação.

## Verificação

- Terraform 1.16.2 baixado em pasta temporária, com SHA256 conferido.
- Provider AWS 6.64.0 assinado pela HashiCorp e lock versionado.
- terraform fmt -check -recursive: aprovado.
- terraform init -backend=false -input=false: aprovado.
- terraform validate: aprovado.
- terraform test: 9 aprovados, 0 falhas, com mock_provider AWS.
- Exemplos de tfvars analisados e formatados pelo Terraform.

## Decisões

- Escopo atual: TC3-09, implementar CI/CD com plan em PR e apply após merge,
  homologação e produção separados. Nenhum apply real executado nesta sessão.
- Região exemplo us-east-1; Single-AZ de laboratório por padrão.
- RDS privado com TLS, backups de 7 dias, proteção contra exclusão e
  snapshot final obrigatório por padrão, com identificador explícito.
- SGs novos autorizam o banco; associá-los às aplicações ou informar SGs
  existentes faz parte da implantação dos projetos Lambda/EKS.
- Mocks não validam quotas, versão/classe regional, IAM real ou conexão TCP.

## Próximos passos na conta do aluno

1. Instalar Terraform/AWS CLI, configurar credenciais e copiar o exemplo.
2. Ajustar região, VPC e SGs das aplicações; revisar plan e executar apply.
3. Integrar Lambda/EKS e demonstrar conexão TLS e configurações no console.
4. Desativar proteção antes de destruir e revisar backups/snapshots retidos.

## Aprendizados

Overrides de data sources nos testes substituem os defaults do mock;
fornecer também vpc_id e map_public_ip_on_launch nos overrides de subnet.

## Correção da CI — 2026-09-13

- Run 34770105563 falhou no validate: o lock tinha h1 do Windows e hashes zh,
  mas não tinha h1 do Linux. O init com -lockfile=readonly verificou o pacote
  assinado, porém não salvou o h1 necessário para verificar o provider extraído.
- Erro reproduzido em container Linux com Terraform 1.16.2 e o lock original.
- terraform providers lock -platform=windows_amd64 -platform=linux_amd64
  acrescentou somente o h1 do Linux, mantendo AWS 6.64.0 e os hashes existentes.
- Windows e Linux: fmt, init com -lockfile=readonly, validate e os nove testes
  com AWS simulada aprovados; SHA256 do lock inalterado após cada execução.
- README documenta como preparar o lock para ambas as plataformas.
- Correção local; envio ao GitHub e nova execução da CI pendentes.

## Quick Tasks Completed

| # | Descrição | Data | Commit | Status |
| --- | --- | --- | --- | --- |
| 001 | Checksums do provider para Windows/Linux na CI | 2026-09-13 | fix(terraform): lock AWS provider for Windows and Linux | Done |

## Ambiente temporário — 2026-09-13

- Usuário autorizou configurar o acesso à conta 213284176265, região us-east-1.
- Credenciais recebidas salvas somente em ~/.aws/credentials, profile default;
  região e saída JSON em ~/.aws/config. Nenhum arquivo AWS anterior existia.
- terraform.tfvars local, ignorado pelo Git, criado a partir do exemplo,
  com aws_region e aws_account_id para o ambiente informado.
- Provider usa allowed_account_ids quando aws_account_id é definido;
  o comportamento existente é mantido quando essa variável é null.
- fmt, validate e nove testes com mock_provider aprovados.
- Falta AWS_SESSION_TOKEN da mesma sessão das credenciais temporárias.
  Não tentar autenticação, plan ou apply antes de completar a sessão.
- AWS CLI não está instalada. Terraform 1.16.2 permanece disponível na
  pasta temporária tc3-05-terraform-tools.
- Quick task 002: configuração preparada; validação do acesso pendente do token.

## TC3-09 — Implementação concluída em 2026-09-13

- Workflow Terraform CI/CD: push valida; PR interno para develop/main planeja;
  PR closed com merged=true gera plano novo e aplica o arquivo salvo.
- develop seleciona homologacao/staging; main seleciona producao/prod.
- Backend S3 parcial com encrypt e use_lockfile; chave própria por ambiente.
  Terraform mínimo elevado para 1.10; CI permanece em 1.16.2.
- Ambientes versionados em environments/*/environment.tfvars.json, com CIDRs,
  nomes RDS, snapshots e parâmetros de disponibilidade/backup próprios.
- Job de AWS depende de validate, usa Environment e concurrency por ambiente,
  verifica conta, permite OIDC ou secrets, exige token para chave temporária
  e rejeita apply de commit superado na branch. Forks/Dependabot sem acesso AWS.
- Windows/Linux: fmt, init sem backend, validate e 11 testes aprovados
  (nove existentes e um por ambiente). Testes também verificam contrato
  staging/prod nos arquivos e chaves corretas de state.
- actionlint 1.7.12 aprovado. Dez cenários dos scripts reais preflight/apply
  aprovados com comandos simulados e sem chamadas AWS.
- README e docs/cicd.md documentam preparação S3/IAM/OIDC/secrets, configuração
  de environments, branches, migração de state e execução local.
- Commits: 38613b5 (backend/ambientes), ddb2445 (pipeline), 5ec9512 (contratos).

### Ativação pendente

- Publicar os commits locais e a branch develop no GitHub.
- Preparar/verificar bucket e IAM e configurar variables/secrets dos ambientes.
  gh variable list e gh secret list retornaram HTTP 403; não foi possível
  consultar/configurar essas definições com a autenticação atual.
- Completar a sessão AWS com token correspondente ou configurar role OIDC.
- Executar PR/merge em homologação e promover por PR para produção.
- Nenhum plan/apply real ou recurso de backend criado nesta sessão.
