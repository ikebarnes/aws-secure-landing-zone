variable "home_region" {
  description = "Region where IAM Identity Center, CloudTrail, and GuardDuty are managed."
  type        = string
  default     = "us-east-1"
}

variable "admin_user" {
  description = "Your own IAM Identity Center user."
  type = object({
    user_name   = string
    given_name  = string
    family_name = string
    email       = string
  })
}

variable "log_retention_days" {
  description = "How long CloudTrail logs are kept before deletion (cost control)."
  type        = number
  default     = 365
}
