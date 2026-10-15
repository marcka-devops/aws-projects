# Security policy

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's private reporting instead: **Security → Report a vulnerability** on this repository. You will get a reply within a few days.

Include what you found, where (file and line, or resource), and how to reproduce it.

## How the project handles security

| Control | Where |
| --- | --- |
| No long-lived AWS keys in CI | GitHub OIDC roles, `infra/stacks/00-bootstrap/github_oidc.tf` |
| Apply only from a protected environment | The apply role trusts only the `production` GitHub environment |
| Least-privilege IAM, MFA, permissions boundary | `infra/stacks/20-security/iam.tf` |
| Audit and threat detection | CloudTrail (all regions, log validation), GuardDuty, IAM Access Analyzer |
| Encryption | S3 SSE, EBS, Aurora, ElastiCache at rest and in transit, Kinesis, Secrets Manager |
| Network isolation | Private tiers without internet routes, VPC endpoints, NACLs, narrow peering |
| Static analysis on every pull request | Checkov, TFLint, cfn-lint, ansible-lint, ShellCheck |
| Instance access | Session Manager by default; SSH only from `admin_cidr` |

## Supported versions

Only the `main` branch is maintained.
