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

- Não executar apply: escopo é entregar o projeto; nenhuma conta AWS foi
  indicada. Não há recursos provisionados nem credenciais manipuladas.
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

