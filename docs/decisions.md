# Design Decisions

Why this landing zone is built the way it is. Each entry records the choice, the reasoning, and what I'd change at production scale.

---

## 1. Separate AWS accounts for security, dev, and prod

**Decision:** Workloads run in dedicated member accounts grouped into Security and Workloads OUs, not in one shared account.

**Why:** An AWS account is the strongest isolation boundary available. A compromised or misconfigured dev environment can't reach prod, and costs and permissions stay cleanly separated.

**In production:** Add a dedicated Log Archive account, a shared Network account, and sandbox accounts per team.

---

## 2. Service control policies as guardrails

**Decision:** Two SCPs: one restricts member accounts to approved regions (us-east-1, us-west-2), and one blocks CloudTrail tampering and leaving the organization.

**Why:** SCPs cap what anyone in a member account can do, including administrators, so a single mistake or stolen credential can't disable audit logging or spin up resources in unmonitored regions. Global services (IAM, Organizations, billing, Route 53) are exempted from the region rule because they run in us-east-1 behind the scenes.

**Verified:** Tested from the prod account. The allowed region worked; the blocked region, stopping CloudTrail, and leaving the org were all denied by SCP. Evidence is in `docs/screenshots/01` through `05`.

---

## 3. Terraform state in S3 with native locking

**Decision:** Remote state in a versioned, encrypted, TLS-only S3 bucket using `use_lockfile = true`, with no DynamoDB lock table.

**Why:** Terraform 1.10 added native S3 state locking, which makes the older DynamoDB lock table unnecessary. One fewer resource to manage and pay for, with the same protection against two people applying at once.

**Also:** The bootstrap stack that creates the bucket keeps its own state locally, because a bucket can't store the state of the code that creates it. Each component (`organization`, `security-baseline`) has its own state file, so a mistake in one can't corrupt the others.

---

## 4. AWS accounts are protected from deletion

**Decision:** Member accounts use `prevent_destroy` and `close_on_deletion = false`.

**Why:** Closing an AWS account is slow, rate-limited, and hard to reverse. Accounts cost nothing to keep, so a stray `terraform destroy` should never be able to remove one.

---

## 5. IAM Identity Center: single-Region instance

**Decision:** Enabled IAM Identity Center as a single-Region organization instance in us-east-1, encrypted with an AWS-owned key.

**Why:** It keeps lab costs at zero (no customer-managed KMS key) and provides every feature this project needs: permission sets, groups, and access across all accounts.

**In production:** I'd use a multi-Region instance so engineers can still sign in during a us-east-1 outage, and a customer-managed KMS key where compliance requires control over encryption keys.

---

## 6. Access through SSO groups, not users or access keys

**Decision:** Permissions are granted to groups (Admins, Developers, Auditors) through permission sets. No permissions are attached to individual users, and no long-lived access keys exist. The temporary IAM user used for the first deployment was deleted once SSO was working.

**Why:** Group-based access makes onboarding and offboarding a one-step change. SSO issues short-lived credentials that expire in hours, removing the most common source of AWS credential leaks. Terraform itself runs through an SSO session.

---

## 7. Organization-wide CloudTrail

**Decision:** One multi-region organization trail, created in the management account, with log file validation enabled and a lifecycle rule that deletes logs after 365 days.

**Why:** It captures API activity in every account, including accounts added later. Member accounts can see the trail but can't change or delete it, and an SCP blocks them from tampering with logging. Log file validation proves the logs weren't altered, which matters for audits under NIST and similar frameworks.

**Current limitation:** The log bucket lives in the management account. The target design moves logs to a dedicated log archive account with S3 Object Lock, so even management-account admins can't alter them.

**Encryption:** Logs are encrypted at rest with S3-managed keys (SSE-S3) to keep lab costs at zero. In production, I'd use a customer-managed KMS key so log access can be restricted and audited separately from S3 permissions.

---

## 8. GuardDuty now, Security Hub with AWS Config later

**Decision:** GuardDuty is enabled in the management account. Security Hub is enabled later, alongside AWS Config and the NIST 800-171 conformance pack.

**Why:** Security Hub's compliance checks depend on AWS Config, so enabling it before Config would produce empty results and cost money for nothing. GuardDuty was enabled in the management account while the Security account was waiting on an account quota increase. Now that the Security account exists, the next step is to make it the delegated administrator for GuardDuty and Security Hub, following AWS's recommended pattern of keeping security tooling out of the management account.

---

## 9. Break-glass access

**Decision:** The emergency path into the organization, for when IAM Identity Center is unavailable or misconfigured, is the root user of the management account. It's protected with MFA, has no access keys, and is used only in emergencies. All root activity is recorded by the organization CloudTrail.

**Why:** Once SSO is the only way in, an SSO outage or a bad permission change could lock every engineer out. A locked-down organization without a documented emergency path tends to get loosened in a hurry during the first outage, which is worse than planning for it up front. The break-glass path deliberately lives in the management account, the one place SCPs can't block it.

**Next step:** Write a short runbook covering when break-glass use is allowed, how to sign in, and what to do afterward, and test it on a schedule.

**In production:** Two dedicated break-glass identities with hardware MFA, credentials stored in a vault with access split between people, an EventBridge rule that alerts the security team the moment either one signs in, and a quarterly test of the full procedure.

---

## Challenges

**Account quota on a new organization.** New organizations start with a very low account limit (2 here), so creating the dev and security accounts failed partway through the apply. I requested an increase through Service Quotas and tested the guardrails on the prod account in the meantime. Once the increase was approved, running `terraform apply` again created only the two missing accounts, because Terraform recognized that everything else already existed. Re-running the security baseline then gave the new accounts the correct SSO access automatically.

**SSO login failing with "Invalid start URL."** The CLI config still held a placeholder portal address. Newer Identity Center instances use a portal URL format (`*.portal.<region>.app.aws`) that differs from most tutorials. I corrected the config, cleared the cached login, and the SSO login worked.
