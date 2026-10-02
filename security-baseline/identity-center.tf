# ------------------------------------------------------------------
# IAM Identity Center (SSO)
# The Identity Center instance itself is enabled once in the console;
# Terraform reads it here and manages everything inside it.
# ------------------------------------------------------------------
data "aws_ssoadmin_instances" "this" {}
data "aws_organizations_organization" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  # Every account in the org, by name. "management" is added explicitly.
  # Accounts that don't exist yet (dev, security while the quota request
  # is pending) are simply skipped, and picked up on the next apply.
  accounts = merge(
    { management = data.aws_organizations_organization.this.master_account_id },
    { for a in data.aws_organizations_organization.this.non_master_accounts : a.name => a.id }
  )

  # Permission sets = job roles. Named after the AWS managed policy they use.
  permission_sets = {
    AdministratorAccess = { description = "Full admin, short sessions", duration = "PT4H" }
    PowerUserAccess     = { description = "Build everything except IAM", duration = "PT8H" }
    ReadOnlyAccess      = { description = "View-only, for audit and support", duration = "PT8H" }
  }

  groups = {
    Admins     = "Platform administrators"
    Developers = "Application developers"
    Auditors   = "Read-only access for audit and compliance"
  }

  # Who gets what, where. This table IS the access policy for the org.
  assignment_rules = [
    { group = "Admins", permission_set = "AdministratorAccess", accounts = ["management", "security", "dev", "prod"] },
    { group = "Developers", permission_set = "PowerUserAccess", accounts = ["dev"] },
    { group = "Developers", permission_set = "ReadOnlyAccess", accounts = ["prod"] },
    { group = "Auditors", permission_set = "ReadOnlyAccess", accounts = ["management", "security", "dev", "prod"] },
  ]

  assignments = {
    for a in flatten([
      for r in local.assignment_rules : [
        for acct in r.accounts : {
          key            = "${r.group}-${r.permission_set}-${acct}"
          group          = r.group
          permission_set = r.permission_set
          account_id     = local.accounts[acct]
        } if contains(keys(local.accounts), acct)
      ]
    ]) : a.key => a
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.permission_sets

  name             = each.key
  description      = each.value.description
  instance_arn     = local.sso_instance_arn
  session_duration = each.value.duration
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.permission_sets

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}

resource "aws_identitystore_group" "this" {
  for_each = local.groups

  identity_store_id = local.identity_store_id
  display_name      = each.key
  description       = each.value
}

resource "aws_identitystore_user" "admin" {
  identity_store_id = local.identity_store_id
  user_name         = var.admin_user.user_name
  display_name      = "${var.admin_user.given_name} ${var.admin_user.family_name}"

  name {
    given_name  = var.admin_user.given_name
    family_name = var.admin_user.family_name
  }

  emails {
    value   = var.admin_user.email
    primary = true
  }
}

resource "aws_identitystore_group_membership" "admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.this["Admins"].group_id
  member_id         = aws_identitystore_user.admin.user_id
}

# Access is granted to GROUPS, never directly to users. Adding a new
# engineer = adding them to a group, with no policy changes.
resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.assignments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.this[each.value.group].group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = each.value.account_id

  depends_on = [aws_ssoadmin_managed_policy_attachment.this]
}
