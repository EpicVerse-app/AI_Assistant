# ── ECS Cluster ───────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # sends CPU/memory/network metrics to CloudWatch
  }

  tags = { Name = "${var.project_name}-cluster" }
}

# ── Task Definition ───────────────────────────────────────────────────────────
# Describes the container: image, CPU/memory, env vars, secrets, logging.
# Secrets are fetched from Secrets Manager by the execution role at startup
# and injected as environment variables — they never appear in the task def.

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.app_cpu
  memory                   = var.app_memory

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${aws_ecr_repository.api.repository_url}:${var.app_image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
        }
      ]

      # Plain environment variables — non-sensitive config only.
      environment = [
        { name = "PORT",                  value = tostring(var.app_port) },
        { name = "ENVIRONMENT",           value = var.environment },
        { name = "LOG_FORMAT",            value = "json" },
        { name = "LOG_LEVEL",             value = "INFO" },
        { name = "ALLOWED_ORIGINS",       value = var.allowed_origins },
        { name = "MAX_UPLOAD_BYTES",      value = local.max_upload_bytes },
        { name = "STORAGE_BACKEND",       value = "s3" },
        { name = "STORAGE_BUCKET",        value = aws_s3_bucket.storage.bucket },
        { name = "AWS_REGION",            value = var.aws_region },
        {
          name  = "RATE_LIMIT_STORAGE_URI"
          value = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379/0"
        },
      ]

      # Sensitive values — pulled from Secrets Manager at task startup.
      # Each entry injects the secret's plain-text value as an env var.
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = aws_secretsmanager_secret.database_url.arn
        },
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        },
        {
          name      = "OPENAI_API_KEY"
          valueFrom = aws_secretsmanager_secret.openai_api_key.arn
        },
        {
          name      = "SARVAM_API_KEY"
          valueFrom = aws_secretsmanager_secret.sarvam_api_key.arn
        },
        {
          name      = "API_KEY"
          valueFrom = aws_secretsmanager_secret.api_key.arn
        },
      ]

      # Ship all container stdout/stderr to CloudWatch Logs.
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }

      # Let ECS know the container is healthy before routing traffic.
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60 # extra grace period for alembic upgrade on startup
      }
    }
  ])

  tags = { Name = "${var.project_name}-task-def" }
}

# ── ECS Service ───────────────────────────────────────────────────────────────
# Keeps `desired_count` tasks running and replaces any that fail.
# New deploys use rolling updates (minimum 50% healthy, maximum 200%).

resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.app_desired_count
  launch_type     = "FARGATE"

  # Replace old tasks before stopping them (reduces downtime during deploys).
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false # tasks use the NAT gateway for outbound traffic
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = var.app_port
  }

  # Wait for the ALB listener to exist before creating the service,
  # otherwise ECS fails to register targets.
  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy_attachment.ecs_execution_managed,
  ]

  # Prevent Terraform from reverting manual scaling changes between applies.
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = { Name = "${var.project_name}-service" }
}
