output "permission_sets" {
  value = { for k, p in aws_ssoadmin_permission_set.this : k => p.arn }
}

output "account_assignments" {
  description = "Which group has which access in which account"
  value       = keys(local.assignments)
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.cloudtrail.bucket
}

output "org_trail_arn" {
  value = aws_cloudtrail.org.arn
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.this.id
}
