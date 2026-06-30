# ── S3 Bucket — Audio & Meeting Artifacts ────────────────────────────────────
# Stores uploaded WAV files and all pipeline outputs (transcripts, MoM JSON/MD).
# The bucket name is suffixed with the AWS account ID to ensure global uniqueness.

resource "aws_s3_bucket" "storage" {
  bucket = "${var.project_name}-storage-${data.aws_caller_identity.current.account_id}"

  tags = { Name = "${var.project_name}-storage" }
}

# Block all public access — objects are accessed only by ECS tasks via IAM.
resource "aws_s3_bucket_public_access_block" "storage" {
  bucket = aws_s3_bucket.storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning so accidentally deleted meeting files can be recovered.
resource "aws_s3_bucket_versioning" "storage" {
  bucket = aws_s3_bucket.storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt objects at rest with the default AWS-managed S3 key (SSE-S3).
# Upgrade to SSE-KMS if you need tighter key controls or audit trails.
resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle: move old meeting files to cheaper storage after 90 days,
# and expire them after 1 year. Adjust to match your retention policy.
resource "aws_s3_bucket_lifecycle_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "archive-old-meetings"
    status = "Enabled"

    filter {
      prefix = "meetings/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 365
    }
  }
}
