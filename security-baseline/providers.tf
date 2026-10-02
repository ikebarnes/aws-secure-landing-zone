provider "aws" {
  region  = var.home_region
  profile = "mgmt"

  default_tags {
    tags = {
      Project   = "aws-secure-landing-zone"
      ManagedBy = "terraform"
      Owner     = "ikebarnes"
    }
  }
}
