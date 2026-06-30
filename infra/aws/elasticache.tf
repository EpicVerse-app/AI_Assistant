# ── ElastiCache Redis ─────────────────────────────────────────────────────────
# Used by slowapi for rate limiting shared across all ECS tasks.
# A single-node cluster is sufficient for rate limiting workloads.
# Upgrade to a replication group for HA if needed.

resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.project_name}-redis-subnets"
  description = "Private subnets for ElastiCache Redis"
  subnet_ids  = aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-redis-subnet-group" }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  # Automatic minor version upgrades during the maintenance window.
  auto_minor_version_upgrade = true
  maintenance_window         = "sun:05:00-sun:06:00" # UTC

  # Snapshots — keep 1 daily snapshot for recovery.
  snapshot_retention_limit = 1
  snapshot_window          = "04:00-05:00" # UTC, before maintenance window

  tags = { Name = "${var.project_name}-redis" }
}
