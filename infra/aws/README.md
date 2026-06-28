# AWS production deployment

Reference infrastructure for running the AI Assistant API on ECS Fargate with RDS and S3.

## What this provides

| Checklist item | Location |
|----------------|----------|
| RDS security group locked to ECS only | `main.tf` — `aws_security_group.rds` allows port 5432 only from `aws_security_group.ecs_api` |
| Secrets in Secrets Manager (not plaintext in task def) | `ecs-task-definition.example.json` — `secrets` block references ARNs |
| S3 for audio + meeting artifacts | App env: `STORAGE_BACKEND=s3`, `STORAGE_BUCKET=...` |
| API key auth | App env: `API_KEY`, `REQUIRE_API_KEY=true` |

## Terraform (RDS + security groups + S3)

```bash
cd infra/aws
cp terraform.tfvars.example terraform.tfvars   # edit vpc_id and subnet_ids
terraform init
terraform plan
terraform apply
```

Create `terraform.tfvars`:

```hcl
aws_region         = "ap-south-1"
vpc_id             = "vpc-xxxxxxxx"
private_subnet_ids = ["subnet-aaa", "subnet-bbb"]
```

## Secrets Manager

Create secrets (JSON or plain string):

- `ai-assistant/database-url` → `postgresql+psycopg2://user:pass@host:5432/ai_assistant`
- `ai-assistant/sarvam-api-key`
- `ai-assistant/openai-api-key`
- `ai-assistant/api-key`

Grant the ECS **task execution role** `secretsmanager:GetSecretValue` on these ARNs.

## ECS task definition

Use `ecs-task-definition.example.json` as a template. Replace `ACCOUNT_ID`, bucket name, and secret ARNs. **Do not** put API keys in the `environment` block — only in `secrets`.

The task **role** (not execution role) needs S3 permissions on the storage bucket:

- `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`, `s3:ListBucket`, `s3:HeadObject`

## Local Docker smoke test (production-like env)

```bash
cd backend
docker build -t ai-assistant-api .
docker run --rm -p 8001:8000 \
  -e SARVAM_API_KEY=test \
  -e OPENAI_API_KEY=test \
  -e DATABASE_URL="sqlite:///./database/ai_assistant.db" \
  -e STORAGE_BACKEND=local \
  -e REQUIRE_API_KEY=false \
  ai-assistant-api
curl http://127.0.0.1:8001/health
```

Expected: `{"status":"ok","database":"ok","storage_backend":"local"}`
