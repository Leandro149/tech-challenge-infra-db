# Executado separadamente com cada environment.tfvars.json real.
mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:rds-test-ABC123"
        kms_key_id    = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
        secret_status = "active"
      }]
    }
  }
}

run "environment_configuration" {
  command = plan

  assert {
    condition     = contains(["staging", "prod"], var.environment) && jsondecode(file("environments/homologacao/environment.tfvars.json")).environment == "staging" && jsondecode(file("environments/producao/environment.tfvars.json")).environment == "prod"
    error_message = "Os arquivos de homologação e produção devem selecionar staging e prod, respectivamente."
  }

  assert {
    condition     = can(regex("(?m)^key\\s*=\\s*\"tech-challenge-infra-db/${var.environment == "prod" ? "producao" : "homologacao"}/terraform\\.tfstate\"\\s*$", file("environments/${var.environment == "prod" ? "producao" : "homologacao"}/backend.hcl")))
    error_message = "Os backends devem usar as chaves próprias de homologação e produção, sem compartilhar state."
  }

  assert {
    condition     = aws_db_instance.this.identifier == "${var.project_name}-${var.environment}-postgres" && aws_cloudwatch_log_group.postgresql.name == "/aws/rds/instance/${var.project_name}-${var.environment}-postgres/postgresql"
    error_message = "Os identificadores RDS e logs devem separar os ambientes."
  }

  assert {
    condition     = aws_vpc.this[0].cidr_block == var.vpc_cidr && (var.environment == "prod" ? var.vpc_cidr == "10.40.0.0/16" : var.vpc_cidr == "10.30.0.0/16")
    error_message = "Homologação e produção devem criar redes com CIDRs distintos."
  }

  assert {
    condition     = var.environment == "prod" ? aws_db_instance.this.multi_az && aws_db_instance.this.backup_retention_period >= 14 : !aws_db_instance.this.multi_az && aws_db_instance.this.backup_retention_period == 7
    error_message = "Produção deve usar Multi-AZ e pelo menos 14 dias de backup; homologação usa Single-AZ e 7 dias."
  }

  assert {
    condition     = aws_db_instance.this.deletion_protection && !aws_db_instance.this.skip_final_snapshot && aws_db_instance.this.final_snapshot_identifier == "${var.project_name}-${var.environment}-final"
    error_message = "Os ambientes devem ter proteção contra exclusão e nomes de snapshots próprios."
  }
}
