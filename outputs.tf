output "vpc_id" {
  description = "VPC que deve ser compartilhada pelo RDS, Lambda e EKS."
  value       = local.vpc_id
}

output "database_subnet_ids" {
  description = "Subnets privadas do banco."
  value       = local.database_subnet_ids
}

output "application_subnet_ids" {
  description = "Subnets para configurar a Lambda e integrar a rede do EKS."
  value       = local.application_subnet_ids
}

output "database_security_group_id" {
  description = "Security Group do RDS."
  value       = aws_security_group.database.id
}

output "lambda_security_group_id" {
  description = "SG a associar à configuração VPC da Lambda."
  value       = aws_security_group.client["lambda"].id
}

output "eks_security_group_id" {
  description = "SG de acesso ao banco para os nodes ou pods do EKS; não basta associá-lo somente ao control plane."
  value       = aws_security_group.client["eks"].id
}

output "rds_identifier" {
  description = "Identificador da instância RDS."
  value       = aws_db_instance.this.identifier
}

output "database_host" {
  description = "Hostname privado do banco, sem porta."
  value       = aws_db_instance.this.address
}

output "database_port" {
  description = "Porta do PostgreSQL."
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Nome do banco inicial."
  value       = aws_db_instance.this.db_name
}

output "database_master_secret_arn" {
  description = "ARN do secret administrado pelo RDS. Não contém a senha."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "database_secret_read_policy_arn" {
  description = "Policy de leitura do secret para associar a roles autorizadas."
  value       = aws_iam_policy.database_secret_read.arn
}

output "secrets_manager_endpoint_id" {
  description = "Endpoint privado do Secrets Manager, se criado."
  value       = try(aws_vpc_endpoint.secrets_manager[0].id, null)
}

