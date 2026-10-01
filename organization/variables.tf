variable "home_region" {
  description = "Region where Terraform runs and most workloads live."
  type        = string
  default     = "us-east-1"
}

variable "allowed_regions" {
  description = "The only regions member accounts may use. Everything else is denied by SCP."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

variable "account_emails" {
  description = "One unique, never-before-used email per new account."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["security", "dev", "prod"] : contains(keys(var.account_emails), k)])
    error_message = "account_emails must include keys: security, dev, prod."
  }
}
