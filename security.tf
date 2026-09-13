resource "aws_security_group" "database" {
  name_prefix = "${local.name}-database-"
  description = "PostgreSQL somente a partir dos SGs autorizados"
  vpc_id      = local.vpc_id

  tags = { Name = "${local.name}-database" }
}

# Estes SGs precisam ser associados às ENIs da Lambda ou aos nodes/pods do EKS.
resource "aws_security_group" "client" {
  for_each    = toset(["lambda", "eks"])
  name_prefix = "${local.name}-${each.key}-db-client-"
  description = "Acesso do cliente ${each.key} ao PostgreSQL"
  vpc_id      = local.vpc_id

  tags = { Name = "${local.name}-${each.key}-db-client" }
}

data "aws_security_group" "existing_client" {
  for_each = var.existing_client_security_group_ids
  id       = each.value
}

resource "aws_vpc_security_group_ingress_rule" "database" {
  for_each                     = local.client_security_group_ids
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL do cliente ${each.key}"

  lifecycle {
    precondition {
      condition     = alltrue([for sg in data.aws_security_group.existing_client : sg.vpc_id == local.vpc_id])
      error_message = "Os SGs de clientes existentes devem pertencer à mesma VPC do banco."
    }
  }
}

resource "aws_vpc_security_group_egress_rule" "client_database" {
  for_each                     = aws_security_group.client
  security_group_id            = each.value.id
  referenced_security_group_id = aws_security_group.database.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL no RDS"
}

resource "aws_security_group" "secrets_endpoint" {
  count       = var.create_secrets_manager_endpoint ? 1 : 0
  name_prefix = "${local.name}-secrets-endpoint-"
  description = "HTTPS dos clientes autorizados ao Secrets Manager"
  vpc_id      = local.vpc_id

  tags = { Name = "${local.name}-secrets-endpoint" }
}

resource "aws_vpc_security_group_ingress_rule" "secrets_endpoint" {
  for_each                     = var.create_secrets_manager_endpoint ? local.client_security_group_ids : {}
  security_group_id            = aws_security_group.secrets_endpoint[0].id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Secrets Manager do cliente ${each.key}"
}

resource "aws_vpc_security_group_egress_rule" "client_secrets" {
  for_each                     = var.create_secrets_manager_endpoint ? aws_security_group.client : {}
  security_group_id            = each.value.id
  referenced_security_group_id = aws_security_group.secrets_endpoint[0].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Leitura da senha via endpoint privado"
}

