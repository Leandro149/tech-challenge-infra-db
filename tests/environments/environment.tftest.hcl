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
