# ADR 0002: GitHub Actions authenticates to AWS with OIDC

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

CI needs AWS access to plan and apply. Storing access keys in GitHub secrets means long-lived credentials that must be rotated and can leak.

## Decision

GitHub's OIDC provider is trusted in IAM. Two roles: a read-only plan role any branch can assume, and an admin apply role only the protected `production` environment can assume.

## Consequences

- No AWS keys exist anywhere in GitHub.
- Applies require a reviewer through the environment protection rule.
- The bootstrap stack must be applied by hand once, before CI can do anything.
