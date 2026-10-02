# ------------------------------------------------------------------
# GuardDuty: continuous threat detection from CloudTrail, VPC flow,
# and DNS logs. Enabled in the management account for now; once the
# Security account exists, it becomes the delegated administrator
# and GuardDuty is turned on org-wide from there.
# ------------------------------------------------------------------
resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = "SIX_HOURS"
}
