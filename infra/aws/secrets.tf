# ── Secrets Manager ───────────────────────────────────────────────────────────
# Terraform creates the secret *shells* here (name + description).
# You populate the actual secret values manually after `terraform apply`:
#
#   aws secretsmanager put-secret-value \
#     --secret-id ai-assistant/openai-api-key \
#     --secret-string "sk-proj-..."
#
# The ECS task definition (ecs.tf) injects these as env vars at container start.
# They are NEVER written to the Terraform state file.
#
# ── DATABASE_URL ──────────────────────────────────────────────────────────────
# After apply, get the RDS password from:
#   aws secretsmanager get-secret-value \
#     --secret-id $(terraform output -raw rds_master_secret_arn) \
#     | jq -r '.SecretString | fromjson | .password'
#
# Then set the database-url secret to:
#   postgresql://ai_assistant:<password>@<rds_endpoint>/ai_assistant

resource "aws_secretsmanager_secret" "database_url" {
  name                    = "${var.project_name}/database-url"
  description             = "Full PostgreSQL connection URL for the FastAPI backend."
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-database-url" }
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}/jwt-secret"
  description             = "Secret key used to sign and verify JWT tokens. Min 32 chars."
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-jwt-secret" }
}

resource "aws_secretsmanager_secret" "openai_api_key" {
  name                    = "${var.project_name}/openai-api-key"
  description             = "OpenAI API key (sk-proj-...)."
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-openai-api-key" }
}

resource "aws_secretsmanager_secret" "sarvam_api_key" {
  name                    = "${var.project_name}/sarvam-api-key"
  description             = "Sarvam AI API subscription key."
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-sarvam-api-key" }
}

# Optional — only needed if you enable API key authentication middleware.
resource "aws_secretsmanager_secret" "api_key" {
  name                    = "${var.project_name}/api-key"
  description             = "Static API key for the X-API-Key middleware (optional)."
  recovery_window_in_days = 7

  tags = { Name = "${var.project_name}-api-key" }
}
