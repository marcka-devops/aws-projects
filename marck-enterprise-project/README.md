<div align="center">

# Marck Enterprise on AWS

**A two-region AWS platform, designed, built and delivered entirely as code.**

[![CI](https://github.com/marcka-devops/aws-projects/actions/workflows/marck-enterprise-ci.yml/badge.svg)](https://github.com/marcka-devops/aws-projects/actions/workflows/marck-enterprise-ci.yml)
[![Terraform](https://github.com/marcka-devops/aws-projects/actions/workflows/marck-enterprise-terraform.yml/badge.svg)](https://github.com/marcka-devops/aws-projects/actions/workflows/marck-enterprise-terraform.yml)
![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A51.10-7B42BC?logo=terraform&logoColor=white)
![AWS provider](https://img.shields.io/badge/hashicorp%2Faws-6.x-FF9900?logo=amazonwebservices&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[Overview](#overview) · [Architecture](#architecture) · [How it was built](#how-it-was-built) · [Quick start](#quick-start) · [Case studies](docs/case-studies.md) · [Documentation](docs/)

</div>

---

## Overview

**Marck Enterprise** is a fictional company with branch offices across the country. It needs to serve a branch-reporting application with high availability, collect device data for near real-time analysis, host its public website, and let developers test code without waiting on operations.

This project delivers that platform on AWS. It combines **ten AWS architecture case studies** (networking, identity, compute, storage, databases, delivery and configuration management) into a single coherent system rather than ten isolated exercises, and it is built the way a platform team would run it in production:

- Every resource is defined in code and changed only through reviewed pull requests.
- Continuous integration checks every change before it merges, with no stored cloud credentials.
- Application releases are promoted automatically from QA to production across two regions, with rollback on failure.

![Delivery workflow](docs/architecture/delivery-workflow.png)

### At a glance

| | |
| --- | --- |
| **Scope** | 10 case studies, 49 individual tasks, each mapped to code ([coverage](docs/case-studies.md)) |
| **Regions** | us-east-1 (production) and us-west-2 (warm standby with local reads) |
| **Networks** | 4 VPCs: production (5 tiers × 2 AZs), development, Oregon, and on-demand developer test stacks |
| **Infrastructure as code** | 8 Terraform stacks, 3 reusable modules, 1 CloudFormation product, 1 Packer image |
| **Quality gates** | 7 automated checks on every pull request |
| **Release path** | Build → QA → smoke test → production in two regions → Elastic Beanstalk |
| **Status** | Validated in CI (Terraform validate, linting, security scanning, unit tests). Deploying needs your own AWS account and domain; see [cost](#cost) |

## Architecture

![AWS architecture](docs/architecture/aws-architecture.png)

| Layer | Design |
| --- | --- |
| **Edge** | `app.<domain>` → Route 53 → Global Accelerator → Application Load Balancer in us-east-1 or us-west-2. `www.<domain>` → CloudFront → private S3 bucket; requests for any other host name receive the error page |
| **Compute** | Auto Scaling groups of 2–6 instances per region: one instance is added when CPU stays above 80% and removed when it stays below 60%. Shared files on FSx for OpenZFS |
| **Network** | Production VPC with five tiers across two Availability Zones: `web` (public), `app1` and `dbcache` (outbound through NAT), `app2` and `db` (no internet route). The development VPC is peered to production, and only the database tiers can reach each other, on MySQL |
| **Data** | Aurora MySQL Global Database: writer and reader in Virginia, reader with write forwarding in Oregon, 2-day automated backups. Valkey cache for repeated branch reports. Kinesis → Lambda for near real-time device analytics |
| **Delivery** | GitHub → CodeCommit mirror → CodePipeline: build → QA → smoke test → production (both regions) → Elastic Beanstalk |
| **Operations** | Systems Manager (Session Manager, State Manager with Ansible), CloudWatch alarms, SNS, CloudTrail, GuardDuty, IAM Access Analyzer, AWS Budgets |

Both diagrams are editable: open [`docs/architecture/marck-enterprise.drawio`](docs/architecture/marck-enterprise.drawio) in [draw.io](https://app.diagrams.net), then run `make diagrams` to refresh the images.

## How it was built

The project was built in the order a platform would be stood up in a real account: decide the design, lay the foundation, then add each layer on top of the last, with automation and documentation alongside.

### 1. Analyze the requirements

- Read all ten case-study briefs and broke them into 49 individual tasks.
- Grouped overlapping tasks (for example, three briefs each ask for web servers, a load balancer or DNS) so each would be built once and reused.
- Placed every task into one company scenario, Marck Enterprise, so the pieces connect instead of standing alone.
- Flagged requirements that can no longer be met as written. AWS retired OpsWorks Stacks in May 2024, so the configuration-management task needed a supported replacement.

### 2. Design the architecture

- Chose two regions: N. Virginia for production and Oregon for warm standby and cross-region reads.
- Planned non-overlapping address space: `10.0.0.0/16` production, `10.1.0.0/16` development, `10.2.0.0/16` Oregon, `10.3.0.0/16` developer test stacks.
- Mirrored every production subnet tier across two Availability Zones for high availability.
- Defined the request path (Route 53 → Global Accelerator → load balancers), the data path (Aurora Global Database with a cache in front) and the release path (QA before production).
- Recorded each non-obvious choice as an [architecture decision record](docs/adr/), with the reasoning and trade-offs.

### 3. Lay the foundation

- Split Terraform into eight stacks with separate state, applied in numbered order, so each change has a small blast radius ([ADR 0001](docs/adr/0001-terraform-stacks.md)).
- Built `00-bootstrap`: an encrypted, versioned S3 bucket for Terraform state, with native S3 locking.
- Set up GitHub OIDC with two IAM roles: a read-only role for plans and an apply role that only the protected `production` environment can use. No AWS access keys are stored anywhere ([ADR 0002](docs/adr/0002-github-oidc.md)).

### 4. Build the network (`10-network`)

- Wrote reusable `vpc` and `nacl` modules. Subnets are declared as named tiers that say how each one reaches the internet.
- Created the production (4-tier), development (2-tier) and Oregon VPCs.
- Peered production and development, with routes and rules that let only the two database tiers talk, on port 3306.
- Added stateless network ACLs per tier, VPC endpoints for S3 and Session Manager, and VPC Flow Logs.
- Kept all shared security groups in this stack so later stacks can reference each other without circular dependencies ([ADR 0007](docs/adr/0007-security-groups-in-network-stack.md)).

### 5. Secure the account (`20-security`)

- Implemented the IAM case study: a console user, a group that can only launch and stop EC2 instances, and permissions to create VPCs, subnets, NACLs, security groups and small encrypted RDS instances.
- Hardened it: MFA required for every action, a strict password policy, a permissions boundary that blocks privilege escalation, and a region restriction.
- Turned on account-wide auditing and detection: multi-region CloudTrail with log validation, GuardDuty, IAM Access Analyzer, an SNS alert topic and a monthly cost budget.

### 6. Build the data layer (`30-data`)

- Deployed Aurora MySQL as a Global Database, with a writer and reader across two AZs in Virginia, a secondary cluster in Oregon with write forwarding, and 2-day backups ([ADR 0006](docs/adr/0006-aurora-global-database.md)).
- Stored connection details in Secrets Manager, replicated to Oregon.
- Fixed the brief's latency problem with a Valkey (Redis-compatible) cache in the `dbcache` tier.
- Built near real-time analytics: devices write to a Kinesis stream, and a Lambda function summarizes events per branch into S3 and CloudWatch metrics.

### 7. Build storage and the website (`40-storage`)

- Created a versioned assets bucket that deletes objects after 75 days, with a Lambda function that runs on every upload.
- Hosted the static website in a private S3 bucket behind CloudFront with a TLS certificate.
- Wrote a CloudFront Function that serves the error page whenever the site is reached by the wrong host name.

### 8. Build compute and the edge (`50-compute`)

- Wrote the `web_fleet` module: a load balancer, an Auto Scaling group, and the 80%/60% CPU scaling alarms. It is used once per region.
- Put Global Accelerator in front of both regions and pointed `app.<domain>` at it.
- Mounted a shared FSx for OpenZFS file system on the production fleet ([ADR 0005](docs/adr/0005-fsx-for-openzfs.md)).
- Launched one instance in every subnet, named after the subnet, as the VPC case study asks.
- Covered the remaining instance tasks: an extra network interface with its own IP for SSH, two extra EBS volumes, and daily snapshots copied to Oregon.
- Replaced OpsWorks with Ansible playbooks that Systems Manager applies and re-applies daily to correct drift ([ADR 0003](docs/adr/0003-ansible-instead-of-opsworks.md)).

### 9. Build the application and release pipeline (`60-delivery`)

- Wrote a small PHP application with tests, a health check, CodeDeploy lifecycle hooks and the "Updated Hello World" page from the brief.
- Mirrored the GitHub repository to CodeCommit on every push to `main`, which meets the brief's migration requirement while keeping GitHub as the place for reviews ([ADR 0004](docs/adr/0004-codecommit-mirror.md)).
- Built a CodePipeline release:
  1. Build and test with CodeBuild.
  2. Deploy to QA.
  3. Smoke-test QA.
  4. Deploy to production in both regions, one instance at a time with automatic rollback.
  5. Deploy the same build to Elastic Beanstalk.
- Packaged the release once so every environment runs the identical build.
- Added a Packer template that bakes the web server image and copies it to Oregon.

### 10. Enable developer self-service (`70-self-service`)

- Wrote a CloudFormation template for a three-tier test environment:
  - The web tier allows HTTP and SSH.
  - The app tier allows SSH only from the web subnet.
  - The RDS MySQL tier allows connections only from the app subnet.
- Set the template to keep the database, and the network it sits in, when developers delete the stack.
- Published it as a Service Catalog product with a launch role, so developers can create environments without broad AWS permissions.

### 11. Automate quality gates

- Added GitHub Actions workflows:
  - **CI** runs Terraform format and validate, TFLint, Checkov, cfn-lint, ansible-lint, ShellCheck, and the PHP and Python unit tests.
  - **Terraform** plans every stack on pull requests and applies them in order after approval.
  - **Mirror** keeps CodeCommit in sync with GitHub.
  - **Golden AMI** builds the Packer image.
- Added pre-commit hooks, Dependabot updates for Actions and Terraform providers, code owners, and pull-request and issue templates.

### 12. Verify

- Validated all eight Terraform stacks, linted the CloudFormation template, and ran the Lambda unit tests locally.
- Opened the change as a pull request so CI ran the full suite on Linux. TFLint flagged that the cache used AWS's default parameter group, which cannot be modified later; it now has its own.

### 13. Document

- Drew the delivery workflow and the AWS architecture in draw.io, using native AWS icons so the diagrams stay editable.
- Wrote a [case-study coverage map](docs/case-studies.md) that links every task to its code and to a command that checks it.
- Wrote [runbooks](docs/runbooks.md) for EBS changes, S3 version restores, regional failover, rollbacks and configuration drift.
- Wrote a [cost and teardown guide](docs/cost-and-teardown.md) and a [getting-started guide](docs/getting-started.md).

## What it demonstrates

| Practice | Implementation |
| --- | --- |
| **Infrastructure as code** | Terraform stacks with separate state, reusable modules, a consistent file layout, and feature toggles for cost |
| **Keyless CI/CD** | GitHub Actions authenticates to AWS through OIDC; applies need approval in a protected environment |
| **Shift-left quality and security** | Seven automated checks on every pull request, plus pre-commit hooks locally |
| **Progressive delivery** | One build promoted through QA to two production regions, with smoke tests and automatic rollback |
| **Immutable infrastructure** | Packer golden AMI copied across regions; rolling instance refresh |
| **Configuration as code** | Ansible through Systems Manager State Manager, with daily drift correction |
| **Self-service platform** | Service Catalog product backed by a least-privilege launch role |
| **Security by default** | Least-privilege IAM, MFA, permissions boundary, private tiers, encryption at rest and in transit, audit and threat detection ([SECURITY.md](SECURITY.md)) |
| **Resilience** | Multi-AZ tiers, Aurora Global Database, Global Accelerator across regions, cross-region snapshots |
| **Operability** | Alarms to SNS, a cost budget, runbooks, and recorded design decisions |

## Tech stack

| Area | Tools |
| --- | --- |
| Cloud | AWS: VPC, EC2, Auto Scaling, Elastic Load Balancing, Global Accelerator, Route 53, CloudFront, S3, Aurora, ElastiCache, Kinesis, Lambda, FSx, IAM, KMS, Secrets Manager, Systems Manager, Service Catalog, CloudFormation, CodeCommit, CodeBuild, CodeDeploy, CodePipeline, Elastic Beanstalk, CloudWatch, CloudTrail, GuardDuty |
| Infrastructure as code | Terraform, CloudFormation, Packer |
| CI/CD | GitHub Actions, AWS CodePipeline |
| Configuration management | Ansible, AWS Systems Manager |
| Quality and security | TFLint, Checkov, cfn-lint, ansible-lint, ShellCheck, pre-commit, Dependabot |
| Application | PHP 8, Python 3.13 |

## Repository structure

```
aws-projects/
├── .github/                      Repository root: GitHub only runs workflows from here
│   ├── workflows/                marck-enterprise-ci · -terraform · -codecommit-mirror · -packer
│   ├── ISSUE_TEMPLATE/           Bug and improvement forms
│   └── CODEOWNERS · dependabot.yml · pull_request_template.md
└── marck-enterprise-project/     This project
    ├── app/                      PHP branch portal, CodeDeploy hooks, buildspecs, tests
    ├── config/ansible/           Playbooks applied by Systems Manager
    ├── docs/
    │   ├── architecture/         draw.io source and PNG exports
    │   ├── adr/                  Architecture decision records
    │   ├── getting-started.md
    │   ├── case-studies.md       Every case-study task → code → how to check it
    │   ├── runbooks.md
    │   └── cost-and-teardown.md
    ├── functions/                Lambda functions and unit tests
    ├── infra/
    │   ├── modules/              vpc · nacl · web_fleet
    │   ├── stacks/               00-bootstrap → 70-self-service (apply in order)
    │   └── cloudformation/       Developer test-stack template
    ├── packer/                   Golden AMI
    ├── website/                  Static site for www.<domain>
    ├── Makefile                  make help
    └── CHANGELOG.md · CONTRIBUTING.md · SECURITY.md · LICENSE
```

See [infra/README.md](infra/README.md) for what each stack creates and the available feature toggles.

## Quick start

**Prerequisites:** an AWS account, Terraform 1.10 or later, the AWS CLI, a domain you can delegate to Route 53, and GNU Make.

```bash
git clone https://github.com/marcka-devops/aws-projects.git
cd aws-projects/marck-enterprise-project

# 1. One-time bootstrap: state bucket and GitHub OIDC roles
terraform -chdir=infra/stacks/00-bootstrap init
terraform -chdir=infra/stacks/00-bootstrap apply -var github_owner=<your-github-user>

# 2. Settings: state bucket, domain, your IP address, GitHub user
cp infra/settings.env.example infra/settings.env

# 3. Apply every stack in order
make apply-all
```

Then connect GitHub so pull requests produce plans and merges apply them. The full walkthrough is in [docs/getting-started.md](docs/getting-started.md).

## Cost

With default settings the platform costs about **$1.40 per hour** (roughly $1,000 per month), mostly for the Aurora Global Database. It is designed to be deployed, demonstrated and torn down. The [cost and teardown guide](docs/cost-and-teardown.md) lists lower-cost settings and the safe teardown order.

## Case studies

| # | Case study | Implemented in |
| --- | --- | --- |
| 1 | EC2, EBS, EFS | `50-compute`, `packer/` |
| 2 | IAM | `20-security` |
| 3 | ELB, Auto Scaling, Route 53 | `modules/web_fleet`, `50-compute` |
| 4 | VPC and peering | `10-network`, `50-compute` |
| 5 | S3 versioning and website hosting | `40-storage`, `website/` |
| 6 | Database architecture | `30-data` |
| 7 | Multi-tier architecture | `infra/cloudformation/`, `70-self-service` |
| 8 | Automation and configuration management | `60-delivery`, `40-storage`, `config/ansible/` |
| 9 | FSx, Global Accelerator, network interfaces | `50-compute` |
| 10 | AWS DevOps (CI/CD) | `60-delivery`, [`.github/workflows/`](../.github/workflows) |

The [coverage map](docs/case-studies.md) lists every task, where it is implemented, and how to verify it.

## Roadmap

- AWS WAF on CloudFront and the load balancers before taking real customer traffic
- A multi-account layout with AWS Organizations (separate production, development and security accounts)
- Blue/green deployments for the web fleets
- Containerized version of the application on Amazon ECS

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the branch, commit and review workflow.

## Author

**Marck Altidor**, DevOps Engineer and Cloud Architect · [GitHub @marcka-devops](https://github.com/marcka-devops)

Released under the [MIT License](LICENSE).
