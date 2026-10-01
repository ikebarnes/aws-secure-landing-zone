terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in S3. use_lockfile = true uses S3's native locking
  # (Terraform 1.10+), which replaces the older DynamoDB lock table.
  # Backend blocks can't use variables, so paste your bucket name below.
  backend "s3" {
    bucket       = "ikebarnes-tfstate-481503225728"
    key          = "organization/terraform.tfstate"
    region       = "us-east-1"
    profile      = "mgmt"
    encrypt      = true
    use_lockfile = true
  }
}
