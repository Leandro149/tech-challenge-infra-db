# Infraestrutura PostgreSQL — TC3-05

Criar um projeto Terraform reproduzível para a atividade da pós-graduação,
provisionando RDS PostgreSQL e acesso privado controlado para Lambda e EKS.

## Objetivos e escopo

- RDS privado, criptografado, com senha gerenciada, TLS, backups e logs.
- Criar VPC/subnets ou reutilizar a rede existente do projeto de aplicações.
- Autorizar tráfego PostgreSQL por identidade de Security Group.
- Entregar exemplos, instruções e validação local sem provisionar recursos reais.

Stack: Terraform >= 1.9, provider HashiCorp AWS 6.x, Amazon RDS PostgreSQL 16.
Lambda, cluster EKS, migrations e criação de usuários SQL são responsabilidade
dos projetos de aplicação. Nenhuma conta/região específica foi informada;
us-east-1 é o exemplo configurável. Não executar apply nesta implementação.

