terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Same state bucket as organization/, different key, so each part of
  # the project has its own state file. Check the bucket name matches
  # the one in organization/versions.tf.
  backend "s3" {
    bucket       = "ikebarnes-tfstate-481503225728"
    key          = "security-baseline/terraform.tfstate"
    region       = "us-east-1"
    profile      = "mgmt"
    encrypt      = true
    use_lockfile = true
  }
}
