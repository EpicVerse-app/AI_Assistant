# ── Networking ────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (ECS, RDS, Redis)."
  value       = aws_subnet.private[*].id
}

# ── ALB ───────────────────────────────────────────────────────────────────────

output "alb_dns_name" {
  description = "ALB DNS name — point your domain's CNAME record here."
  value       = aws_lb.api.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID — use this for Route 53 alias records."
  value       = aws_lb.api.zone_id
}

# ── ECR ───────────────────────────────────────────────────────────────────────

output "ecr_repository_url" {
  description = "Full ECR repository URL to tag and push your Docker image to."
  value       = aws_ecr_repository.api.repository_url
}

# ── RDS ───────────────────────────────────────────────────────────────────────

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (host:port). Use in your DATABASE_URL secret."
  value       = aws_db_instance.postgres.endpoint
}

output "rds_master_secret_arn" {
  description = "ARN of the RDS-managed master password secret in Secrets Manager."
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
}

# ── ElastiCache ───────────────────────────────────────────────────────────────

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint address."
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

# ── S3 ────────────────────────────────────────────────────────────────────────

output "storage_bucket_name" {
  description = "S3 bucket name for audio files and meeting artifacts."
  value       = aws_s3_bucket.storage.bucket
}

# ── CloudWatch ────────────────────────────────────────────────────────────────

output "log_group_name" {
  description = "CloudWatch log group where ECS container logs are shipped."
  value       = aws_cloudwatch_log_group.api.name
}

# ── IAM ───────────────────────────────────────────────────────────────────────

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role (used by the running app)."
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role (used by the ECS agent)."
  value       = aws_iam_role.ecs_execution.arn
}

# ── Helpful next-step commands ────────────────────────────────────────────────

output "docker_push_command" {
  description = "Command to authenticate Docker with ECR and push a new image."
  value       = <<-EOT
    # 1. Authenticate
    aws ecr get-login-password --region ${var.aws_region} \
      | docker login --username AWS --password-stdin \
          ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com

    # 2. Build and push
    docker build -t ${aws_ecr_repository.api.repository_url}:$GIT_SHA ./backend
    docker push ${aws_ecr_repository.api.repository_url}:$GIT_SHA
  EOT
}
