# Infraestrutura PostgreSQL e CI/CD — TC3-05 / TC3-09

Criar um projeto Terraform reproduzível para a atividade da pós-graduação,
provisionando RDS PostgreSQL e acesso privado controlado para Lambda e EKS.

## Objetivos e escopo

- RDS privado, criptografado, com senha gerenciada, TLS, backups e logs.
- Criar VPC/subnets ou reutilizar a rede existente do projeto de aplicações.
- Autorizar tráfego PostgreSQL por identidade de Security Group.
- Entregar exemplos, instruções e validação local sem provisionar recursos reais.
- Executar plan em PR e apply após merge, separando homologação e produção
  com configurações, autenticação e state S3 por ambiente.

Stack: Terraform >= 1.10, provider HashiCorp AWS 6.x, Amazon RDS PostgreSQL 16,
GitHub Actions e backend S3 com locking nativo.
Lambda, cluster EKS, migrations e criação de usuários SQL são responsabilidade
dos projetos de aplicação. Ambiente temporário informado: conta 213284176265,
us-east-1. Configuração da pipeline não executa deploy real nesta sessão;
faltam token AWS e preparação do backend/GitHub Environments.
