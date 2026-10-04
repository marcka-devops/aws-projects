# Marck Multi-Region Corp.

A multi-region AWS platform for one web application, written as a single Terraform root module.

![marck-devops-corp architecture](architecture.jpeg)

Production runs in Northern Virginia. Oregon keeps a warm web fleet and an Aurora reader so traffic can move without a database promotion. Development is a separate network, peered only so the database subnets can reach each other on MySQL. The test network is not peered. Deleting the test stack leaves the database in place.

## How a request moves

1. `app.marck-devops-corp.example` is a Route 53 alias to Global Accelerator.
2. The accelerator sends traffic to an Application Load Balancer in Virginia or Oregon.
3. Each load balancer fronts an Auto Scaling group. The group stays between 2 and 6 instances, adds one when CPU stays above 80% for two minutes, and removes one when CPU stays below 60% for five minutes.
4. HTTP redirects to HTTPS. The static site at `www` is a private S3 bucket served through CloudFront.

Failover of the DNS name does not promote the Oregon database. Promoting the reader is a separate step.

## What the networks allow

| Network | CIDR | Role |
| --- | --- | --- |
| Production | `10.0.0.0/16` | Web, app1, app2, dbcache, and db, each in two Availability Zones |
| Development | `10.1.0.0/16` | Web and database only. Peered to production for MySQL |
| Oregon | `10.2.0.0/16` | Warm web fleet and the Aurora reader |
| Test | `10.3.0.0/16` | Isolated three-tier stack for developers |

App1 and the cache subnets can reach the internet through a NAT gateway in each Availability Zone. App2 has no internet route. It reaches S3 through a gateway endpoint and Session Manager through interface endpoints. The database subnets have no internet route. SSH is not open to the internet. Administrators reach a bastion from a configured network, and Session Manager is the normal path onto an instance.

## Data and delivery

Aurora MySQL is a global cluster: a writer in Virginia, a reader in Oregon, encrypted, deletion-protected, with two days of backups. Redis in the cache subnets absorbs repeated reads. Kinesis takes telemetry, and a Lambda function archives those events. Shared files for the web fleet are on FSx for Lustre.

GitLab assumes the deploy role with OIDC, so the pipeline does not store AWS keys. One revision goes to QA on the development web instance, then to the production Auto Scaling group through CodeDeploy, then to the PHP environment on Elastic Beanstalk. A website change does not replace Aurora. Platform changes stay in this Terraform module.

## Terraform

Resource files are in [`terraforms/`](terraforms), one file per resource type. `terraform validate` passes. State stays on this machine until the state bucket from the first apply exists.

Before any apply, copy `terraforms/terraform.tfvars.example` and set:

- `domain_name` to a DNS name you control
- `admin_cidr` to the real administrator network

The names in this module are examples. Persistent Lustre starts at 1200 GiB, which is the minimum for that storage class and the expensive part of an apply.

## Sheets

| Sheet | What it shows |
| --- | --- |
| [Overview](diagrams/01-architecture-overview.jpeg) | Regions, VPCs, and the request path |
| [Network](diagrams/02-network-and-peering.jpeg) | Subnets, NAT, and the narrow peering path |
| [Compute and edge](diagrams/03-compute-scaling-and-edge.jpeg) | Load balancers, scaling, and CloudFront |
| [Data](diagrams/04-data-and-storage.jpeg) | Aurora, Redis, S3, and Lustre |
| [Delivery](diagrams/05-delivery-and-automation.jpeg) | QA, production, and Beanstalk |
| [Access](diagrams/06-security-and-access.jpeg) | IAM, security groups, and Session Manager |
