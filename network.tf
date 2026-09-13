data "aws_availability_zones" "available" {
  count = local.create_vpc ? 1 : 0
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required", "opted-in"]
  }
}

resource "aws_vpc" "this" {
  count                = local.create_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }

  lifecycle {
    precondition {
      condition     = length(data.aws_availability_zones.available[0].names) >= 2
      error_message = "A região precisa disponibilizar pelo menos duas zonas."
    }
  }
}

resource "aws_subnet" "database" {
  count                   = local.create_vpc ? 2 : 0
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available[0].names[count.index]
  map_public_ip_on_launch = false

  tags = { Name = "${local.name}-database-${count.index + 1}" }
}

resource "aws_subnet" "application" {
  count                   = local.create_vpc ? 2 : 0
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone       = data.aws_availability_zones.available[0].names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${local.name}-application-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Somente a rota local da VPC: sem Internet Gateway ou NAT nas subnets criadas.
resource "aws_route_table" "private" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = local.vpc_id

  tags = { Name = "${local.name}-private" }
}

resource "aws_route_table_association" "database" {
  count          = local.create_vpc ? 2 : 0
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_route_table_association" "application" {
  count          = local.create_vpc ? 2 : 0
  subnet_id      = aws_subnet.application[count.index].id
  route_table_id = aws_route_table.private[0].id
}

data "aws_subnet" "existing_database" {
  for_each = var.existing_database_subnet_ids
  id       = each.value
}

data "aws_subnet" "existing_application" {
  for_each = var.existing_application_subnet_ids
  id       = each.value
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-database"
  subnet_ids = local.database_subnet_ids

  tags = { Name = "${local.name}-database" }

  lifecycle {
    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.existing_application : subnet.vpc_id == local.vpc_id && !subnet.map_public_ip_on_launch])
      error_message = "As subnets existentes de aplicação devem pertencer à VPC informada e não atribuir IP público automaticamente. Verifique também suas rotas."
    }

    precondition {
      condition     = alltrue([for subnet in data.aws_subnet.existing_database : subnet.vpc_id == local.vpc_id && !subnet.map_public_ip_on_launch])
      error_message = "As subnets existentes do banco devem pertencer à VPC informada e não atribuir IP público automaticamente. Verifique também suas rotas."
    }

    precondition {
      condition     = local.create_vpc ? true : length(toset([for subnet in data.aws_subnet.existing_database : subnet.availability_zone])) >= 2
      error_message = "As subnets do RDS devem estar em pelo menos duas zonas distintas."
    }
  }
}

resource "aws_vpc_endpoint" "secrets_manager" {
  count               = var.create_secrets_manager_endpoint ? 1 : 0
  vpc_id              = local.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = local.application_subnet_ids
  security_group_ids  = [aws_security_group.secrets_endpoint[0].id]

  tags = { Name = "${local.name}-secrets-manager" }

  lifecycle {
    precondition {
      condition     = local.create_vpc ? true : length(toset([for subnet in data.aws_subnet.existing_application : subnet.availability_zone])) == length(var.existing_application_subnet_ids)
      error_message = "Para o endpoint Interface, informe somente uma subnet de aplicação por zona."
    }
  }
}
