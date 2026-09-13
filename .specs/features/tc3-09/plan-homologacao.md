# Plano real de homologação — 2026-09-13

Plano gerado e salvo em deployment.tfplan, ignorado pelo Git. Nenhum apply executado.

- Conta: 213284176265.
- Região: us-east-1.
- Ambiente: staging / homologacao.
- Backend: tech-challenge-infra-db-tfstate-213284176265.
- State key: tech-challenge-infra-db/homologacao/terraform.tfstate.
- Ações: 28 criações; zero alterações e zero exclusões.
- Banco: tech-challenge-staging-postgres, PostgreSQL 16, db.t4g.micro.
- Armazenamento: gp3, 20 GiB, criptografado; autoscaling até 100 GiB.
- Single-AZ, privado, porta 5432, backups de 7 dias.
- Senha gerenciada pelo RDS no Secrets Manager; proteção contra exclusão.

Somente o bucket S3 foi criado nesta sessão, com versionamento e bloqueio de acesso público.
O apply permanece no fluxo após merge; um novo plano será gerado pela pipeline.

## Recursos previstos

- aws_cloudwatch_log_group.postgresql
- aws_db_instance.this
- aws_db_parameter_group.this
- aws_db_subnet_group.this
- aws_iam_policy.database_secret_read
- aws_route_table_association.application[0]
- aws_route_table_association.application[1]
- aws_route_table_association.database[0]
- aws_route_table_association.database[1]
- aws_route_table.private[0]
- aws_security_group.client["eks"]
- aws_security_group.client["lambda"]
- aws_security_group.database
- aws_security_group.secrets_endpoint[0]
- aws_subnet.application[0]
- aws_subnet.application[1]
- aws_subnet.database[0]
- aws_subnet.database[1]
- aws_vpc_endpoint.secrets_manager[0]
- aws_vpc_security_group_egress_rule.client_database["eks"]
- aws_vpc_security_group_egress_rule.client_database["lambda"]
- aws_vpc_security_group_egress_rule.client_secrets["eks"]
- aws_vpc_security_group_egress_rule.client_secrets["lambda"]
- aws_vpc_security_group_ingress_rule.database["eks"]
- aws_vpc_security_group_ingress_rule.database["lambda"]
- aws_vpc_security_group_ingress_rule.secrets_endpoint["eks"]
- aws_vpc_security_group_ingress_rule.secrets_endpoint["lambda"]
- aws_vpc.this[0]
