# ── AWS ──────────────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "Región AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "access_key" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

# ── Proyecto ──────────────────────────────────────────────────────────────────
variable "project_name" {
  description = "Prefijo para todos los recursos"
  type        = string
  default     = "banca-g8"
}

variable "image_tag" {
  description = "Tag de la imagen Docker a desplegar"
  type        = string
  default     = "latest"
}

# ── Red ───────────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block para la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs para las subnets públicas (una por AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "azs" {
  description = "Zonas de disponibilidad a utilizar"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── ECS / Fargate ─────────────────────────────────────────────────────────────
variable "task_cpu" {
  description = "CPU units para cada task Fargate (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memoria en MB para cada task Fargate"
  type        = number
  default     = 512
}

variable "accounts_desired_count" {
  description = "Número de tasks para el servicio accounts"
  type        = number
  default     = 1
}

variable "transactions_desired_count" {
  description = "Número de tasks para el servicio transactions"
  type        = number
  default     = 1
}

variable "alerts_desired_count" {
  description = "Número de tasks para el servicio alerts"
  type        = number
  default     = 1
}

# ── RDS PostgreSQL ────────────────────────────────────────────────────────────
variable "db_instance_class" {
  description = "Tipo de instancia RDS (db.t3.micro es free tier eligible)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "Usuario master de la base de datos"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña master de la base de datos (mínimo 8 caracteres)"
  type        = string
  sensitive   = true
}
