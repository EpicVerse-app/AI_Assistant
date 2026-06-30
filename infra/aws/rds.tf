# ── RDS PostgreSQL ────────────────────────────────────────────────────────────
# Production database for users and meetings tables.
# The password is managed by RDS Secrets Manager integration (rotate_immediately).
# After `terraform apply`, retrieve the generated password from:
#   AWS Console → RDS → your instance → Configuration → Master credentials ARN
# Then store that connection string in the ai-assistant/database-url secret
# (see secrets.tf).

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnets"
  description = "Private subnets for RDS"
  subnet_ids  = aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  # Let RDS generate and rotate the password automatically via Secrets Manager.
  # The secret ARN is available at:
  #   aws_db_instance.postgres.master_user_secret[0].secret_arn
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Not reachable from the internet — only accessible from inside the VPC.
  publicly_accessible = false

  # Automated backups — 7-day retention, taken during low-traffic window.
  backup_retention_period = 7
  backup_window           = "02:00-03:00" # UTC
  maintenance_window      = "sun:03:30-sun:04:30"

  # Performance Insights (free tier: 7-day retention on t4g instances).
  performance_insights_enabled = true

  # Set to false for production to prevent accidental deletion.
  # Set to true temporarily if you need to destroy the instance via Terraform.
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-postgres-final-snapshot"

  deletion_protection = true

  tags = { Name = "${var.project_name}-postgres" }
}
