# ADR 0007: Security groups live in the network stack

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

The database security group must allow the web fleet's group, and the web fleet must reference the database. If each stack owned its own groups, the data and compute stacks would depend on each other.

## Decision

All shared security groups are created in `10-network` and exported. Later stacks attach them and never define cross-stack rules.

## Consequences

- No circular dependencies between stacks.
- Changing who can reach the database is a network-stack change, reviewed in one place.
- Groups that only one stack uses (FSx, Lambda) stay in that stack.
