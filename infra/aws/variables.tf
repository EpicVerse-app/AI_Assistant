# ── General ──────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short name used as a prefix for all resource names."
  type        = string
  default     = "ai-assistant"
}

variable "environment" {
  description = "Deployment environment (production, staging, etc.)."
  type        = string
  default     = "production"
}

# ── Networking ────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ, for the ALB)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (ECS, RDS, Redis)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ── ECS / App ─────────────────────────────────────────────────────────────────

variable "app_image_tag" {
  description = "Docker image tag to deploy (e.g. git commit SHA or 'latest')."
  type        = string
  default     = "latest"
}

variable "app_port" {
  description = "Port the FastAPI container listens on."
  type        = number
  default     = 8000
}

variable "app_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 512
}

variable "app_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 1024
}

variable "app_desired_count" {
  description = "Number of ECS tasks to run."
  type        = number
  default     = 1
}

variable "allowed_origins" {
  description = "Comma-separated list of origins allowed by the CORS middleware."
  type        = string
  default     = "https://yourdomain.com"
}

variable "max_upload_bytes" {
  description = "Maximum audio upload size in bytes (default = 604 MB ≈ 5 h WAV). Leave empty to use the value computed in locals."
  type        = string
  default     = ""
}

# ── RDS ───────────────────────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "RDS instance type."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "ai_assistant"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "ai_assistant"
}

# ── ElastiCache (Redis) ───────────────────────────────────────────────────────

variable "redis_node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t4g.micro"
}

# ── HTTPS / ACM ───────────────────────────────────────────────────────────────

variable "acm_certificate_arn" {
  description = "ARN of an ACM certificate covering your API domain (must be in same region)."
  type        = string
  # No default — you must provide this. Request or import a cert in ACM first.
}

variable "domain_name" {
  description = "Your API domain name (e.g. api.yourdomain.com). Used only in outputs."
  type        = string
  default     = "api.yourdomain.com"
}

# ── Locals ────────────────────────────────────────────────────────────────────

locals {
  # 5 hours of WAV audio at 16 kHz, 16-bit mono × 1.1 headroom ≈ 604 MB
  _5h_wav_bytes    = 5 * 3600 * 16000 * 2
  max_upload_bytes = tostring(floor(local._5h_wav_bytes * 1.1))

  # Convenience: two AZs from the region (used by subnets)
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}
