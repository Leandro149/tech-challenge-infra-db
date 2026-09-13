locals {
  name       = "${var.project_name}-${var.environment}"
  create_vpc = var.existing_vpc_id == null
  vpc_id     = local.create_vpc ? aws_vpc.this[0].id : var.existing_vpc_id

  database_subnet_ids    = local.create_vpc ? [for subnet in aws_subnet.database : subnet.id] : sort(tolist(var.existing_database_subnet_ids))
  application_subnet_ids = local.create_vpc ? [for subnet in aws_subnet.application : subnet.id] : sort(tolist(var.existing_application_subnet_ids))

  client_security_group_ids = merge(
    { for name, sg in aws_security_group.client : name => sg.id },
    { for name, id in var.existing_client_security_group_ids : "existing-${name}" => id }
  )
}

