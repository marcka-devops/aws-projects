# Configuration management

Ansible playbooks, applied to instances by AWS Systems Manager State Manager. This replaces the OpsWorks stack from the Automation case study ([ADR 0003](../docs/adr/0003-ansible-instead-of-opsworks.md)).

| Playbook | Applied to | Does |
| --- | --- | --- |
| [`ansible/baseline.yml`](ansible/baseline.yml) | Instances tagged `ConfigManaged=true` | Baseline packages, security updates, time sync, SSH hardening, login banner |
| [`ansible/hello-world.yml`](ansible/hello-world.yml) | Instances tagged `Role=hello-world` | Apache with a Hello World page |

## How it runs

1. Terraform (`infra/stacks/50-compute/config_management.tf`) uploads this folder to the config bucket.
2. The SSM document `marck-enterprise-ApplyPlaybook` installs `ansible-core` if needed, syncs the playbooks, and runs one locally.
3. Two State Manager associations run it by tag once a day, so manual changes are reverted.

Re-apply now: `aws ssm start-associations-once --association-ids <id>`.
