# ADR 0006: Aurora Global Database for production data

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

The Database case study needs high availability, 2-day backups, reads from other regions, and fast recovery. RDS MySQL with cross-region read replicas would work but replicates more slowly and fails over by hand per replica.

## Decision

Aurora MySQL Global Database: writer and reader in Virginia across two AZs, a secondary cluster in Oregon with write forwarding. A Valkey cache in front handles the repeated branch reports.

## Consequences

- Typical cross-region lag under a second; managed failover and switchover.
- Global Database needs memory-optimized instances, which is most of the monthly cost.
- The developer test stack still uses RDS MySQL, as the multi-tier case study asks.
