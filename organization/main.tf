# ------------------------------------------------------------------
# The organization itself. Your current account becomes the
# management account. feature_set = "ALL" is required for SCPs.
# ------------------------------------------------------------------
resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  # Services allowed to work across all accounts (used on Day 3).
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
}

locals {
  root_id = aws_organizations_organization.this.roots[0].id
}

# ------------------------------------------------------------------
# Organizational units: group accounts by purpose so policies can be
# applied once per group instead of once per account.
# ------------------------------------------------------------------
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = local.root_id
}

locals {
  ou_ids = {
    security  = aws_organizations_organizational_unit.security.id
    workloads = aws_organizations_organizational_unit.workloads.id
  }

  # One map drives all accounts. Adding an account = adding one line.
  accounts = {
    security = { name = "security", ou = "security" }
    dev      = { name = "dev", ou = "workloads" }
    prod     = { name = "prod", ou = "workloads" }
  }
}

# ------------------------------------------------------------------
# Member accounts. AWS creates OrganizationAccountAccessRole in each
# one so the management account can administer it.
# ------------------------------------------------------------------
resource "aws_organizations_account" "this" {
  for_each = local.accounts

  name              = each.value.name
  email             = var.account_emails[each.key]
  parent_id         = local.ou_ids[each.value.ou]
  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = false

  lifecycle {
    # AWS accounts are slow and awkward to close. Keep them.
    prevent_destroy = true
    # AWS doesn't return role_name after creation; ignore it so
    # Terraform doesn't try to recreate the account.
    ignore_changes = [role_name]
  }
}
