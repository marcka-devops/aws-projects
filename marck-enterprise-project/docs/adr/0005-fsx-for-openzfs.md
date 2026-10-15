# ADR 0005: FSx for OpenZFS for the shared file system

- **Status:** Accepted
- **Date:** 2026-10-14

## Context

The Organizations case study asks for an FSx file system mounted on two Linux instances. FSx for Lustre, the obvious Linux choice, starts at 1.2 TiB and costs far more than a demo needs.

## Decision

FSx for OpenZFS, single-AZ, 64 GiB, mounted over NFS at `/mnt/shared` by the production fleet.

## Consequences

- Native Linux NFS clients, no extra driver.
- Single-AZ: an AZ outage makes the share unavailable. Use a Multi-AZ deployment type for production data.
