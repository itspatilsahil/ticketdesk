# Run this ONCE, before anything else, to create the remote state backend
# (S3 bucket + DynamoDB lock table) that the main infra/ configuration
# depends on. This little config keeps its own state locally (there's
# nothing to bootstrap for the bootstrapper) - that's normal and fine.
#
# Usage:
#   cd infra/bootstrap
#   terraform init
#   terraform apply -var="owner_initials=sp"

terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "owner_initials" {
  description = "Your initials, used as a resource-name prefix (tkt-<initials>-*)"
  type        = string
}

variable "aws_region" {
  default = "ap-south-1"
  type    = string
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "TicketDesk"
      Owner       = var.owner_initials
      Environment = "dev"
      CostCenter  = "poc-training"
    }
  }
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "tkt-${var.owner_initials}-tfstate"

  # A safety net, not a requirement: prevents `terraform destroy` from ever
  # accidentally deleting the bucket your state files live in.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = "tkt-${var.owner_initials}-tflock"
  billing_mode = "PAY_PER_REQUEST" # no fixed cost - you pay per lock read/write, a few cents for a whole POC
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.tf_state.bucket
}

output "lock_table" {
  value = aws_dynamodb_table.tf_lock.name
}
