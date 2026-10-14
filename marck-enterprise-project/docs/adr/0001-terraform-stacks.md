# ADR 0001: Split Terraform into stacks with separate state

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

One Terraform root for the whole platform would put the VPCs, the database and the pipeline in a single state file. Any change, even a pipeline tweak, would plan against everything, and a mistake could touch the database.

## Decision

Seven stacks under `infra/stacks/`, numbered in apply order, each with its own state file in S3. Later stacks read earlier ones through `terraform_remote_state`.

## Consequences

- A change plans only the stack it touches, and a bad apply is limited to that stack.
- Apply order matters and is encoded in the numbering, the `Makefile` and the apply workflow.
- Cross-stack values must be published as outputs before another stack can use them.
