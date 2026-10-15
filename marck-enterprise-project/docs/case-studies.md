# Case study coverage

Every task from the ten case-study briefs, where it is implemented, and how to check it after `make apply-all`.
The briefs were written for "XYZ Corporation"; here the company is Marck Enterprise.

Commands assume the AWS CLI is signed in to the account and `<domain>` is your `domain_name`.

---

## 1. EC2, EBS, EFS (Module 2)

| Task | Implementation | Check |
| --- | --- | --- |
| Linux web servers in us-east-1 from an AMI | `packer/web-ami.pkr.hcl` builds the image; `50-compute/amis.tf` uses it once `golden_ami_name` is set | `aws ec2 describe-images --owners self --filters Name=name,Values=marck-enterprise-web*` |
| Replicate the instance to us-west-2 | Packer copies the AMI (`ami_regions`); the Oregon fleet launches from it | Same command with `--region us-west-2` |
| Two EBS volumes on the Virginia instance | `var.ebs_volumes` (`data1`, `data2`) on the `web` instance, `50-compute/tier_instances.tf` | `terraform -chdir=infra/stacks/50-compute state list \| grep aws_ebs_volume` |
| Detach and delete one, extend the other | Remove `data2` from `ebs_volumes`, raise `data1.size`, apply; then grow the filesystem | [runbooks.md: EBS volumes](runbooks.md#resize-or-remove-an-ebs-volume) |
| Back up the volume | Data Lifecycle Manager: daily snapshot, 7 kept, copy in us-west-2 | `aws ec2 describe-snapshots --owner-ids self --filters Name=tag:Backup,Values=daily` |

## 2. IAM (Module 3)

| Task | Implementation | Check |
| --- | --- | --- |
| A user that can sign in to the console | `aws_iam_user.ops` + login profile (reset required), `20-security/iam.tf` | Sign in at the `console_sign_in_url` output |
| A group that can only launch and stop EC2 | `marck-enterprise-ec2-operators`: Run/Start/Stop + Describe; terminate is denied | Try to terminate an instance as `marck-ops`: access denied |
| Let the user create VPCs, subnets, NACLs, security groups | `marck-enterprise-network-builders` | Create a VPC as `marck-ops` |
| Let the user create RDS instances | `marck-enterprise-rds-builders` (small, encrypted instances only) | Create a `db.t4g.micro` with encryption as `marck-ops` |
| Secure the permissions | MFA required for everything, password policy, permissions boundary that blocks privilege escalation, region lock, CloudTrail, GuardDuty, Access Analyzer | Sign in without MFA: every action except MFA setup is denied |

## 3. ELB, Auto Scaling, Route 53 (Module 4)

| Task | Implementation | Check |
| --- | --- | --- |
| Add instances when CPU exceeds 80% | `modules/web_fleet`: alarm `cpu-above-80` (2 × 1 min) → +1 | `aws cloudwatch describe-alarms --alarm-name-prefix marck-enterprise-web-east` |
| Remove instances when CPU drops below 60% | Alarm `cpu-below-60` (5 × 1 min) → −1 | Same command |
| Load balancer across the instances | Application Load Balancer, HTTPS, health check `/health.php` | Refresh `https://app.<domain>`; the instance ID changes |
| Route traffic to the company domain | `app.<domain>` → Global Accelerator → both ALBs (`50-compute/fleets.tf`) | `dig app.<domain>` returns the two accelerator IPs |

Load-test the scale-out: `sudo dnf install -y stress-ng && stress-ng --cpu 2 --timeout 600` on a fleet instance through Session Manager.

## 4. VPC and peering (Module 5)

| Task | Implementation | Check |
| --- | --- | --- |
| Production 4-tier network, subnets web (public), app1, app2, dbcache, db (private) | `10-network/vpcs.tf`, each tier in two AZs | VPC console, filter by `marck-enterprise-prod` |
| Instances in every subnet, named after the subnet | `50-compute/tier_instances.tf` (`web`, `app1`, `app2`, `dbcache`, `db`) | `aws ec2 describe-instances --filters Name=tag:Network,Values=production --query 'Reservations[].Instances[].Tags[?Key==\`Name\`].Value'` |
| dbcache and app1 can send internet requests | NAT routes only on `app1` and `dbcache` route tables | From `app1`: `curl -sI https://aws.amazon.com` works; from `app2` it times out |
| Security groups and NACLs | `10-network/security_groups.tf`, `10-network/nacls.tf` | Review in the console |
| Development 2-tier network with web and db | `module.dev_vpc` | VPC console |
| Only web can reach the internet | Dev `web` is public; dev `db` has no route out | From dev `db`: no internet |
| Peering between the networks | `aws_vpc_peering_connection.prod_dev` | `aws ec2 describe-vpc-peering-connections` |
| Connect the two db subnets | Routes only between the db tiers; NACL and SG rules allow MySQL 3306 | From dev `db`: `nc -zv <aurora writer endpoint> 3306` |

## 5. S3 versioning and website hosting (Module 6)

| Task | Implementation | Check |
| --- | --- | --- |
| Store any amount of data, reachable from anywhere | Assets bucket, HTTPS only; share files with pre-signed URLs | `aws s3 presign s3://<assets bucket>/<key> --expires-in 3600` |
| Delete data after 75 days | Lifecycle rule `delete-after-75-days` (current and old versions) | `aws s3api get-bucket-lifecycle-configuration --bucket <assets bucket>` |
| Recover an older version | Versioning enabled | [runbooks.md: restore a file](runbooks.md#restore-an-earlier-version-of-a-file) |
| Static website on the company domain | Private S3 + CloudFront + ACM at `www.<domain>` | Open `https://www.<domain>` |
| Error page when the wrong domain is used | CloudFront Function sends any other host to `error.html` | Open `https://<domain>` or the `cloudfront_domain_name` output |

## 6. Database architecture (Module 7)

| Task | Implementation | Check |
| --- | --- | --- |
| Highly available database, 2-day automated backups | Aurora MySQL, writer + reader in two AZs, `backup_retention_period = 2` | `aws rds describe-db-clusters --db-cluster-identifier marck-enterprise-primary --query 'DBClusters[0].BackupRetentionPeriod'` |
| Read data from different regions | Aurora Global Database, secondary cluster in Oregon with write forwarding | `aws rds describe-global-clusters` |
| Near real-time analysis | Kinesis stream → Lambda → per-branch summaries in S3 + CloudWatch metrics | [runbooks.md: send test events](runbooks.md#send-test-device-events) |
| Fix the latency from repeated reads | Valkey (Redis-compatible) cache in the `dbcache` tier, cache-aside | Endpoint in the `cache_endpoint` output and in the app secret |

## 7. Multi-tier architecture (Module 8)

| Task | Implementation | Check |
| --- | --- | --- |
| Web tier: public subnet, HTTP and SSH from the internet | `infra/cloudformation/dev-test-stack.yaml` `WebSecurityGroup` (SSH limited to a CIDR you enter) | Launch the product; open `WebUrl` |
| App tier: private subnet, SSH only from the web subnet | `AppSecurityGroup` allows 22 from the web subnet CIDR | SSH web → app works; anything else fails |
| DB tier: RDS MySQL, 3306 only from the app subnet | `DbSecurityGroup` allows 3306 from the app subnet CIDR | `nc -zv <DatabaseEndpoint> 3306` from app |
| Route 53 record to the instance | `WebDnsRecord` when a zone and name are given | `dig <RecordName>` |
| Developers test without system admins | Service Catalog product with a launch role (`70-self-service`) | Sign in as a member of `marck-enterprise-developers` and launch it |
| Deleting the stack keeps RDS | `DeletionPolicy: Retain` on the DB and the network pieces it needs | Terminate the product; the DB instance is still there |

## 8. Automation and configuration management (Module 9)

| Task | Implementation | Check |
| --- | --- | --- |
| Beanstalk environment for a PHP application | `60-delivery/beanstalk.tf` (Amazon Linux 2023, PHP 8) | `beanstalk_url` output |
| Upload a PHP page reading "Updated Hello World" | `app/src/hello.php`, released by the pipeline's Beanstalk stage | `<beanstalk_url>/hello.php` |
| Lambda triggered by S3 object creation | `40-storage/assets.tf` + `functions/s3_object_created` | Upload a file; it gets the tag `processed=true` |
| OpsWorks stack with a Hello World page | OpsWorks was retired in May 2024. Ansible playbook `hello-world.yml`, applied by Systems Manager to the instance tagged `Role=hello-world` | `http://<web_tier_public_ip>/` |

## 9. AWS Organizations module (Module 10)

| Task | Implementation | Check |
| --- | --- | --- |
| FSx file system for Linux, mounted on two instances | FSx for OpenZFS, mounted at `/mnt/shared` by the production fleet (min 2) | On a fleet instance: `df -h /mnt/shared` |
| Two Linux EC2 instances running web servers | Production Auto Scaling group, minimum 2 | Target group shows two healthy targets |
| Global Accelerator as the endpoint for both | Accelerator → ALB → both instances (and the Oregon fleet) | `global_accelerator_ips` output |
| Extra network interface; SSH through its IP | `aws_network_interface.web_secondary` + Elastic IP on the `web` instance | `ssh ec2-user@<web_tier_eni_ip>` (needs `ssh_public_key`) |

## 10. AWS DevOps (Module 1)

| Task | Implementation | Check |
| --- | --- | --- |
| Website in GitHub | This repository (`app/`) | — |
| Migrate the GitHub repository to CodeCommit | `.github/workflows/marck-enterprise-codecommit-mirror.yml` pushes `main` to CodeCommit through OIDC | `aws codecommit get-branch --repository-name marck-enterprise --branch-name main` |
| CodeDeploy deployments for QA and production on EC2 | Deployment groups `qa` (dev `web` instance) and `production` (Auto Scaling group) | CodeDeploy console |
| CodePipeline: CodeCommit source, QA then production, production only after QA | `60-delivery/pipeline.tf`: Source → Build → QA (deploy + smoke test) → Production | Push a change and watch the pipeline |
| Third stage to Elastic Beanstalk | `Beanstalk` stage | `beanstalk_url` output |
