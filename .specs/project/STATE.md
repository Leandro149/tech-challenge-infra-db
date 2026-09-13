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

- Escopo atual: configurar o acesso ao ambiente temporário informado pelo
  usuário. Nenhum apply executado; recursos AWS não foram provisionados.
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
