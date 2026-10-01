# ------------------------------------------------------------------
# SCP 1: Deny any action outside the approved regions.
# Global services (IAM, Organizations, billing, Route 53, etc.) live
# in us-east-1 behind the scenes, so they're excluded with
# not_actions, following AWS's documented example.
# ------------------------------------------------------------------
data "aws_iam_policy_document" "deny_unapproved_regions" {
  statement {
    sid    = "DenyOutsideApprovedRegions"
    effect = "Deny"
    not_actions = [
      "account:*",
      "acm:*",
      "aws-marketplace:*",
      "aws-portal:*",
      "budgets:*",
      "ce:*",
      "cloudfront:*",
      "config:*",
      "cur:*",
      "directconnect:*",
      "ec2:DescribeRegions",
      "ec2:DescribeTransitGateways",
      "ec2:DescribeVpnGateways",
      "fms:*",
      "globalaccelerator:*",
      "health:*",
      "iam:*",
      "kms:*",
      "networkmanager:*",
      "organizations:*",
      "pricing:*",
      "route53:*",
      "route53domains:*",
      "s3:GetAccountPublic*",
      "s3:ListAllMyBuckets",
      "s3:PutAccountPublic*",
      "shield:*",
      "sso:*",
      "sts:*",
      "support:*",
      "trustedadvisor:*",
      "waf:*",
      "wafv2:*",
      "wellarchitected:*",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }
}

# ------------------------------------------------------------------
# SCP 2: Protect the security baseline. Nobody in a member account,
# not even an admin, can turn off audit logging or leave the org.
# ------------------------------------------------------------------
data "aws_iam_policy_document" "protect_security_baseline" {
  statement {
    sid    = "DenyCloudTrailTampering"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyLeavingOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "deny_unapproved_regions" {
  name        = "deny-unapproved-regions"
  description = "Restrict member accounts to approved regions"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_unapproved_regions.json

  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_policy" "protect_security_baseline" {
  name        = "protect-security-baseline"
  description = "Block CloudTrail tampering and leaving the organization"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.protect_security_baseline.json

  depends_on = [aws_organizations_organization.this]
}

# Region restriction applies to both OUs.
resource "aws_organizations_policy_attachment" "deny_regions" {
  for_each  = local.ou_ids
  policy_id = aws_organizations_policy.deny_unapproved_regions.id
  target_id = each.value
}

# Baseline protection applies at the root, so it covers every
# member account, including ones added later. (SCPs never apply
# to the management account itself.)
resource "aws_organizations_policy_attachment" "protect_baseline" {
  policy_id = aws_organizations_policy.protect_security_baseline.id
  target_id = local.root_id
}
