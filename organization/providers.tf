provider "aws" {
  region  = var.home_region
  profile = "mgmt"

  # Every resource gets these tags automatically.
  default_tags {
    tags = {
      Project   = "aws-secure-landing-zone"
      ManagedBy = "terraform"
      Owner     = "ikebarnes"
    }
  }
}
