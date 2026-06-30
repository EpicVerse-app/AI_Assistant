terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — create this S3 bucket manually before running `terraform init`.
  # The bucket must exist; Terraform will not create it for you.
  #
  # aws s3api create-bucket \
  #   --bucket <your-tfstate-bucket> \
  #   --region ap-south-1 \
  #   --create-bucket-configuration LocationConstraint=ap-south-1
  #
  # aws s3api put-bucket-versioning \
  #   --bucket <your-tfstate-bucket> \
  #   --versioning-configuration Status=Enabled
  #
  # Then fill in the bucket name and key below and run `terraform init`.

  backend "s3" {
    bucket = "REPLACE_WITH_YOUR_TFSTATE_BUCKET"
    key    = "ai-assistant/terraform.tfstate"
    region = "ap-south-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Current AWS account ID — used to make S3 bucket names globally unique.
data "aws_caller_identity" "current" {}

# Availability zones in the chosen region.
data "aws_availability_zones" "available" {
  state = "available"
}
