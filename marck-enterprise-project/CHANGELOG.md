# Changelog

All notable changes to this project are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- `.github/` (workflows, code owners, Dependabot, templates) moved inside the project folder. The workflows run once `.github/` is at a repository root.
- README rewritten with an overview, project highlights and a step-by-step account of how the platform was built.
- ElastiCache uses its own `valkey8` parameter group (`allkeys-lru`) instead of the non-editable default group, as flagged by TFLint.

## [1.0.0] - 2026-10-14

### Added

- Terraform stacks `00-bootstrap` through `70-self-service`, with shared modules `vpc`, `nacl` and `web_fleet`.
- Production (4-tier), development (2-tier) and Oregon VPCs, with database-only peering between production and development.
- IAM case-study users and groups, MFA enforcement, permissions boundary, CloudTrail, GuardDuty, Access Analyzer, budget alerts.
- Aurora MySQL Global Database, Valkey cache, Kinesis and Lambda device analytics.
- Versioned assets bucket with a 75-day lifecycle and S3-triggered Lambda; static website on CloudFront with a host-name check.
- Web fleets in us-east-1 and us-west-2 behind Global Accelerator, FSx for OpenZFS, EBS volumes with cross-region snapshots.
- Ansible configuration through Systems Manager State Manager (replaces OpsWorks).
- CodePipeline release: build, QA deploy and smoke test, production in both regions, Elastic Beanstalk.
- Service Catalog product for developer test stacks that keep their database on delete.
- GitHub Actions: CI checks, Terraform plan and apply through OIDC, CodeCommit mirror, Packer golden AMI.
- Architecture and delivery diagrams (draw.io), case-study coverage map, runbooks, cost and teardown guide.

[Unreleased]: https://github.com/marcka-devops/aws-projects/compare/marck-enterprise-v1.0.0...HEAD
[1.0.0]: https://github.com/marcka-devops/aws-projects/releases/tag/marck-enterprise-v1.0.0
