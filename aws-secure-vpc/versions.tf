# -----------------------------------------------------------------------------
# versions.tf — Terraform & AWS provider constraints
# -----------------------------------------------------------------------------
# Pin Terraform and the AWS provider so every engineer / CI run gets the same
# provider behavior. Change these only when you intentionally upgrade.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }

  # Optional: uncomment and fill in to use a remote S3 backend for state.
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "aws-secure-vpc/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-terraform-locks"
  #   encrypt        = true
  # }
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
