# Getting started

Deploying Marck Enterprise into your own AWS account, from nothing to a running pipeline.
Read [cost and teardown](cost-and-teardown.md) first: the defaults cost about $1.40 an hour.

## Prerequisites

| Tool | Version |
| --- | --- |
| AWS account | Admin access for the first run |
| [Terraform](https://developer.hashicorp.com/terraform/install) | 1.10 or later |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2, signed in (`aws sts get-caller-identity` works) |
| GNU Make and Bash | Git Bash on Windows works |
| A domain | One you can point at Route 53 name servers |
| A GitHub repository | A copy of [aws-projects](https://github.com/marcka-devops/aws-projects) under your account; commands below run from `marck-enterprise-project/` |

## 1. Bootstrap the state bucket and CI roles

Run once, with local state:

```bash
terraform -chdir=infra/stacks/00-bootstrap init
terraform -chdir=infra/stacks/00-bootstrap apply -var github_owner=<your-github-user>
terraform -chdir=infra/stacks/00-bootstrap output
```

Keep the outputs: `state_bucket`, `github_plan_role_arn`, `github_apply_role_arn`.

## 2. Local settings

```bash
cp infra/settings.env.example infra/settings.env
```

Fill in the state bucket, your domain, your public IP as a `/32`, your GitHub user and an alert email. The file is git-ignored.

## 3. Apply the stacks

One at a time, in order (each shows a plan and asks before applying):

```bash
make apply STACK=10-network
```

After `10-network`, copy the `name_servers` output to your domain registrar. Certificates in `40-storage` and `50-compute` validate only once DNS points at Route 53.

Then continue:

```bash
make apply STACK=20-security
make apply STACK=30-data          # Aurora Global Database: about 20 minutes
make apply STACK=40-storage
make apply STACK=50-compute
make apply STACK=60-delivery
make apply STACK=70-self-service
```

Or run `make apply-all` to go through all of them.

## 4. Connect GitHub

In the repository: **Settings → Secrets and variables → Actions → Variables**.

| Variable | Value |
| --- | --- |
| `AWS_PLAN_ROLE_ARN` | `github_plan_role_arn` from `00-bootstrap` |
| `AWS_APPLY_ROLE_ARN` | `github_apply_role_arn` from `00-bootstrap` |
| `AWS_MIRROR_ROLE_ARN` | `github_mirror_role_arn` from `60-delivery` |
| `TF_STATE_BUCKET` | `state_bucket` from `00-bootstrap` |
| `DOMAIN_NAME` | Your domain |
| `ADMIN_CIDR` | Your IP as `/32` |
| `ALERT_EMAIL` | Where alarms go |

Then **Settings → Environments → New environment** named `production`, with yourself as a required reviewer, and protect `main` so changes arrive only through pull requests.

From here on, pull requests show a plan for every stack and merges apply after approval.

## 5. Ship the application

Push a change under `app/` to `main`. The mirror workflow copies it to CodeCommit, and the pipeline runs: Build → QA → QA smoke test → Production (Virginia and Oregon) → Elastic Beanstalk.

Open the outputs to see it:

```bash
terraform -chdir=infra/stacks/50-compute output app_url
terraform -chdir=infra/stacks/40-storage output website_url
terraform -chdir=infra/stacks/60-delivery output pipeline_console_url
```

## 6. Optional: golden AMI

Run the **Golden AMI** workflow (or `packer build packer` locally), then set `golden_ami_name = "marck-enterprise-web"` in `50-compute` and apply. The instance refresh rolls both fleets onto the new image.
