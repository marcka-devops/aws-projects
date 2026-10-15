# ADR 0003: Ansible through Systems Manager instead of OpsWorks

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

The Automation case study asks for an OpsWorks stack. AWS ended support for OpsWorks Stacks on 26 May 2024; new stacks cannot be created.

## Decision

Configuration lives in Ansible playbooks (`config/ansible/`). A custom SSM document downloads them from S3 and runs them locally. State Manager associations apply them to instances by tag and re-run daily.

## Consequences

- Same outcome as OpsWorks (configure servers from code, keep them configured), on a supported service.
- No SSH, inventory or control node needed; targeting is by tag.
- Instances need outbound access to install `ansible-core` the first time.
