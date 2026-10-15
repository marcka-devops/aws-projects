# Architecture decision records

Short records of the design choices that are not obvious from the code. Each one says what was decided, why, and what it costs.

| ADR | Decision |
| --- | --- |
| [0001](0001-terraform-stacks.md) | Split Terraform into stacks with separate state |
| [0002](0002-github-oidc.md) | GitHub Actions authenticates to AWS with OIDC |
| [0003](0003-ansible-instead-of-opsworks.md) | Ansible through Systems Manager instead of OpsWorks |
| [0004](0004-codecommit-mirror.md) | GitHub is the working repository; CodeCommit is the pipeline source |
| [0005](0005-fsx-for-openzfs.md) | FSx for OpenZFS for the shared file system |
| [0006](0006-aurora-global-database.md) | Aurora Global Database for production data |
| [0007](0007-security-groups-in-network-stack.md) | Security groups live in the network stack |

New decisions: copy the newest file, take the next number, and add a row here.
