terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote backend with locking (checklist item 7). Bucket/table names
  # come from infra/bootstrap - fill them into backend.hcl (see
  # backend.hcl.example) and run: terraform init -backend-config=backend.hcl
  backend "s3" {}
}
