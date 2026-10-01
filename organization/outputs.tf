output "organization_id" {
  value = aws_organizations_organization.this.id
}

output "management_account_id" {
  value = aws_organizations_organization.this.master_account_id
}

output "account_ids" {
  description = "Use these to set up CLI profiles for each account"
  value       = { for k, a in aws_organizations_account.this : k => a.id }
}

output "ou_ids" {
  value = local.ou_ids
}
