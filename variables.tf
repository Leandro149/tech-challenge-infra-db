variable "aws_region" {
  description = "Região AWS dos recursos."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto usado nos identificadores dos recursos."
  type        = string
  default     = "tech-challenge"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,29}$", var.project_name)) && !endswith(var.project_name, "-") && !strcontains(var.project_name, "--")
    error_message = "Use até 30 caracteres: letras minúsculas, números e hífens, iniciando por letra e sem hífens finais ou consecutivos."
  }
}

variable "environment" {
  description = "Ambiente usado nos nomes e tags."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "O ambiente deve ser dev, staging ou prod."
  }
}

variable "tags" {
  description = "Tags adicionais."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR /16 IPv4 da VPC nova; quatro subnets /24 serão criadas."
  type        = string
  default     = "10.30.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/16$", var.vpc_cidr))
    error_message = "Informe um CIDR IPv4 /16 válido."
  }
}

variable "existing_vpc_id" {
  description = "ID da VPC existente do EKS/Lambda. Null cria uma VPC nova."
  type        = string
  default     = null

  validation {
    condition     = var.existing_vpc_id == null ? true : can(regex("^vpc-[0-9a-f]+$", var.existing_vpc_id))
    error_message = "Informe um ID de VPC válido ou null."
  }
}

variable "existing_database_subnet_ids" {
  description = "Subnets privadas existentes do RDS, em ao menos duas zonas da VPC informada."
  type        = set(string)
  default     = []

  validation {
    condition     = var.existing_vpc_id == null ? length(var.existing_database_subnet_ids) == 0 : length(var.existing_database_subnet_ids) >= 2
    error_message = "Ao reutilizar VPC, informe ao menos duas subnets de banco; ao criar VPC, deixe a lista vazia."
  }
}

variable "existing_application_subnet_ids" {
  description = "Subnets privadas das aplicações e do endpoint Secrets Manager na VPC existente."
  type        = set(string)
  default     = []

  validation {
    condition     = var.existing_vpc_id == null ? length(var.existing_application_subnet_ids) == 0 : length(var.existing_application_subnet_ids) >= 2
    error_message = "Ao reutilizar VPC, informe ao menos duas subnets de aplicação; ao criar VPC, deixe a lista vazia."
  }
}

variable "existing_client_security_group_ids" {
  description = "Mapa nome => SG de Lambda/nodes/pods já existentes na mesma VPC. As regras de saída desses SGs permanecem sob responsabilidade do projeto de aplicação."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for id in values(var.existing_client_security_group_ids) : can(regex("^sg-[0-9a-f]+$", id))])
    error_message = "Todos os valores devem ser IDs de Security Group válidos."
  }
}

variable "create_secrets_manager_endpoint" {
  description = "Cria endpoint privado para leitura da senha sem NAT. Desative se a VPC já tiver endpoint ou saída HTTPS apropriada."
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Banco inicial criado no PostgreSQL."
  type        = string
  default     = "techchallenge"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{0,62}$", var.db_name))
    error_message = "Use de 1 a 63 caracteres alfanuméricos, começando por letra."
  }
}

variable "db_username" {
  description = "Usuário administrador. A senha é gerenciada pelo RDS no Secrets Manager."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.db_username)) && !contains(["postgres", "admin", "root", "rdsadmin"], lower(var.db_username))
    error_message = "Use até 63 caracteres (letras, números e underscores), iniciando por letra, e evite usuários reservados."
  }
}

variable "engine_version" {
  description = "Versão PostgreSQL, major ou major.minor. Com major, o RDS escolhe uma minor disponível."
  type        = string
  default     = "16"

  validation {
    condition     = can(regex("^[0-9]{2}(\\.[0-9]+)?$", var.engine_version))
    error_message = "Informe uma versão como 16 ou 16.10, disponível na região AWS."
  }
}

variable "instance_class" {
  description = "Classe da instância RDS. Verifique disponibilidade da classe/versão na região."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Armazenamento inicial gp3, em GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536 && floor(var.allocated_storage) == var.allocated_storage
    error_message = "O armazenamento deve ser um inteiro de 20 a 65536 GiB."
  }
}

variable "max_allocated_storage" {
  description = "Limite de autoscaling, em GiB, pelo menos 10% acima do tamanho inicial."
  type        = number
  default     = 100

  validation {
    condition     = var.max_allocated_storage >= ceil(var.allocated_storage * 1.1) && var.max_allocated_storage <= 65536 && floor(var.max_allocated_storage) == var.max_allocated_storage
    error_message = "O limite deve ser inteiro, até 65536 GiB, e ao menos 10% maior que allocated_storage."
  }
}

variable "multi_az" {
  description = "Habilita standby em outra zona; aumenta o custo."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Retenção dos backups automáticos, em dias. Zero não é permitido."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35 && floor(var.backup_retention_period) == var.backup_retention_period
    error_message = "A retenção de backup deve ser um inteiro entre 1 e 35 dias."
  }
}

variable "deletion_protection" {
  description = "Impede a exclusão do RDS até ser explicitamente desativada e aplicada."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Ignora snapshot final na exclusão; use true somente em laboratório descartável."
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Identificador único do snapshot final. Obrigatório quando skip_final_snapshot=false."
  type        = string
  default     = null

  validation {
    condition     = var.skip_final_snapshot ? true : var.final_snapshot_identifier != null
    error_message = "Informe final_snapshot_identifier ou habilite skip_final_snapshot conscientemente."
  }

  validation {
    condition     = var.final_snapshot_identifier == null ? true : can(regex("^[a-z][a-z0-9-]{0,254}$", var.final_snapshot_identifier)) && !endswith(var.final_snapshot_identifier, "-") && !strcontains(var.final_snapshot_identifier, "--")
    error_message = "O snapshot deve começar por letra minúscula, ter até 255 caracteres e não ter hífens finais/consecutivos."
  }
}

