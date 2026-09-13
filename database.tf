resource "aws_db_parameter_group" "this" {
  name_prefix = "${local.name}-postgres-"
  family      = "postgres${split(".", var.engine_version)[0]}"
  description = "TLS obrigatorio e logs do PostgreSQL"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_min_duration_statement"
    value        = "1000"
    apply_method = "immediate"
  }

  tags = { Name = "${local.name}-postgres" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/instance/${local.name}-postgres/postgresql"
  retention_in_days = 14
}

resource "aws_db_instance" "this" {
  identifier                  = "${local.name}-postgres"
  engine                      = "postgres"
  engine_version              = var.engine_version
  instance_class              = var.instance_class
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true
  port                        = 5432

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period  = var.backup_retention_period
  backup_window            = "03:00-04:00"
  maintenance_window       = "sun:05:00-sun:06:00"
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  auto_minor_version_upgrade      = true
  allow_major_version_upgrade     = false
  apply_immediately               = false
  enabled_cloudwatch_logs_exports = ["postgresql"]
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.final_snapshot_identifier

  tags = { Name = "${local.name}-postgres" }

  depends_on = [aws_cloudwatch_log_group.postgresql]
}

# Associe esta policy à execution role da Lambda ou role do ServiceAccount EKS.
resource "aws_iam_policy" "database_secret_read" {
  name_prefix = "${local.name}-database-secret-read-"
  description = "Leitura somente do secret administrador deste RDS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadDatabaseSecret"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = aws_db_instance.this.master_user_secret[0].secret_arn
    }]
  })
}

