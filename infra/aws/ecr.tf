# ── ECR Repository ────────────────────────────────────────────────────────────
# Stores the Docker image for the FastAPI backend.
#
# Push workflow (run from the repo root after building):
#
#   IMAGE="${aws_ecr_repository.api.repository_url}:${GIT_SHA}"
#   aws ecr get-login-password --region ap-south-1 \
#     | docker login --username AWS --password-stdin \
#         $(aws sts get-caller-identity --query Account --output text).dkr.ecr.ap-south-1.amazonaws.com
#   docker build -t "$IMAGE" ./backend
#   docker push "$IMAGE"
#
# Then update app_image_tag in terraform.tfvars to the new tag and re-apply.

resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}/api"
  image_tag_mutability = "MUTABLE" # allows overwriting 'latest'; switch to IMMUTABLE for prod

  image_scanning_configuration {
    scan_on_push = true # free basic scan — catches known CVEs on every push
  }

  tags = { Name = "${var.project_name}-ecr" }
}

# Keep only the 10 most recent images to control storage costs.
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
