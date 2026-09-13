# Todos os recursos e data sources AWS são simulados: nenhuma chamada à conta.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      vpc_id                  = "vpc-0123456789abcdef0"
      availability_zone       = "us-east-1a"
      map_public_ip_on_launch = false
    }
  }

  mock_data "aws_security_group" {
    defaults = {
      vpc_id = "vpc-0123456789abcdef0"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      address = "postgres.test.internal"
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds-test-ABC123"
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
        secret_status = "active"
      }]
    }
  }
}

variables {
  final_snapshot_identifier = "tc3-test-final-snapshot"
}

run "private_database_defaults" {
  command = apply

  assert {
    condition     = aws_db_instance.this.engine == "postgres" && !aws_db_instance.this.publicly_accessible && aws_db_instance.this.storage_encrypted
    error_message = "O RDS deve ser PostgreSQL privado e criptografado."
  }

  assert {
    condition     = aws_db_instance.this.manage_master_user_password && aws_db_instance.this.password == null
    error_message = "A senha deve ser gerenciada pelo RDS e não fornecida ao Terraform."
  }

  assert {
    condition     = aws_db_instance.this.backup_retention_period == 7 && aws_db_instance.this.deletion_protection && !aws_db_instance.this.skip_final_snapshot && !aws_db_instance.this.delete_automated_backups
    error_message = "Backups e proteção contra exclusão devem estar ativos por padrão."
  }

  assert {
    condition     = anytrue([for parameter in aws_db_parameter_group.this.parameter : parameter.name == "rds.force_ssl" && parameter.value == "1"])
    error_message = "O PostgreSQL deve exigir conexão TLS."
  }

  assert {
    condition     = length(aws_subnet.database) == 2 && length(aws_subnet.application) == 2 && length(toset([for subnet in aws_subnet.database : subnet.availability_zone])) == 2 && alltrue([for subnet in concat(aws_subnet.database, aws_subnet.application) : !subnet.map_public_ip_on_launch])
    error_message = "A rede deve ter quatro subnets privadas e o banco deve cobrir duas AZs."
  }

  assert {
    condition     = length(aws_route_table.private[0].route) == 0
    error_message = "A tabela privada não deve criar rotas externas."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.database) == 2 && alltrue([for rule in aws_vpc_security_group_ingress_rule.database : rule.from_port == 5432 && rule.to_port == 5432 && rule.ip_protocol == "tcp" && rule.cidr_ipv4 == null && rule.cidr_ipv6 == null])
    error_message = "O RDS deve autorizar somente TCP 5432 de SGs, sem CIDR aberto."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.database["lambda"].referenced_security_group_id == output.lambda_security_group_id && aws_vpc_security_group_ingress_rule.database["eks"].referenced_security_group_id == output.eks_security_group_id && alltrue([for rule in aws_vpc_security_group_egress_rule.client_database : rule.referenced_security_group_id == output.database_security_group_id && rule.from_port == 5432 && rule.to_port == 5432])
    error_message = "Lambda e EKS precisam de regras de entrada/saída direcionadas ao banco."
  }

  assert {
    condition     = aws_vpc_endpoint.secrets_manager[0].private_dns_enabled && aws_vpc_endpoint.secrets_manager[0].vpc_endpoint_type == "Interface" && length(aws_vpc_security_group_ingress_rule.secrets_endpoint) == 2 && alltrue([for rule in aws_vpc_security_group_egress_rule.client_secrets : rule.from_port == 443 && rule.to_port == 443 && rule.referenced_security_group_id == aws_security_group.secrets_endpoint[0].id])
    error_message = "A leitura do secret deve ter caminho privado HTTPS."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.database_secret_read.policy).Statement[0].Resource == output.database_master_secret_arn && toset(jsondecode(aws_iam_policy.database_secret_read.policy).Statement[0].Action) == toset(["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"])
    error_message = "A policy IAM deve permitir leitura somente do secret deste banco."
  }
}

run "reuse_existing_vpc" {
  command = apply

  variables {
    existing_vpc_id                 = "vpc-0123456789abcdef0"
    existing_database_subnet_ids    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    existing_application_subnet_ids = ["subnet-0123456789abcdef2", "subnet-0123456789abcdef3"]
    existing_client_security_group_ids = {
      eks_nodes = "sg-0123456789abcdef0"
    }
  }

  override_data {
    target = data.aws_subnet.existing_database["subnet-0123456789abcdef1"]
    values = {
      availability_zone       = "us-east-1b"
      vpc_id                  = "vpc-0123456789abcdef0"
      map_public_ip_on_launch = false
    }
  }

  override_data {
    target = data.aws_subnet.existing_application["subnet-0123456789abcdef3"]
    values = {
      availability_zone       = "us-east-1b"
      vpc_id                  = "vpc-0123456789abcdef0"
      map_public_ip_on_launch = false
    }
  }

  assert {
    condition     = length(aws_vpc.this) == 0 && length(aws_subnet.database) == 0 && length(aws_subnet.application) == 0 && output.vpc_id == "vpc-0123456789abcdef0"
    error_message = "O modo existente não deve criar outra VPC/subnets."
  }

  assert {
    condition     = toset(output.database_subnet_ids) == toset(["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]) && aws_vpc_security_group_ingress_rule.database["existing-eks_nodes"].referenced_security_group_id == "sg-0123456789abcdef0" && aws_vpc_security_group_ingress_rule.secrets_endpoint["existing-eks_nodes"].from_port == 443
    error_message = "As subnets e o SG existente do EKS devem ser integrados."
  }
}

run "reuse_existing_secrets_connectivity" {
  command = plan

  variables {
    create_secrets_manager_endpoint = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.secrets_manager) == 0 && length(aws_security_group.secrets_endpoint) == 0 && length(aws_vpc_security_group_egress_rule.client_secrets) == 0
    error_message = "Não deve duplicar endpoint quando sua criação for desativada."
  }
}

run "reject_disabled_backups" {
  command = plan
  variables { backup_retention_period = 0 }
  expect_failures = [var.backup_retention_period]
}

run "reject_insufficient_autoscaling_limit" {
  command = plan
  variables { max_allocated_storage = 21 }
  expect_failures = [var.max_allocated_storage]
}

run "require_final_snapshot_name" {
  command = plan
  variables { final_snapshot_identifier = null }
  expect_failures = [var.final_snapshot_identifier]
}

run "require_existing_subnets" {
  command = plan
  variables { existing_vpc_id = "vpc-0123456789abcdef0" }
  expect_failures = [var.existing_database_subnet_ids, var.existing_application_subnet_ids]
}

run "reject_database_subnets_in_same_zone" {
  command = plan

  variables {
    existing_vpc_id                 = "vpc-0123456789abcdef0"
    existing_database_subnet_ids    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    existing_application_subnet_ids = ["subnet-0123456789abcdef2", "subnet-0123456789abcdef3"]
    create_secrets_manager_endpoint = false
  }

  expect_failures = [aws_db_subnet_group.this]
}

run "reject_database_subnet_in_wrong_vpc" {
  command = plan

  variables {
    existing_vpc_id                 = "vpc-0123456789abcdef0"
    existing_database_subnet_ids    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    existing_application_subnet_ids = ["subnet-0123456789abcdef2", "subnet-0123456789abcdef3"]
    create_secrets_manager_endpoint = false
  }

  override_data {
    target = data.aws_subnet.existing_database["subnet-0123456789abcdef1"]
    values = {
      availability_zone       = "us-east-1b"
      vpc_id                  = "vpc-abcdef01234567890"
      map_public_ip_on_launch = false
    }
  }

  expect_failures = [aws_db_subnet_group.this]
}
