# Runbooks

Short procedures for the operations the case studies ask for. Connect to instances with Session Manager:

```bash
aws ssm start-session --target <instance-id>
```

Instance IDs are in the `tier_instance_ids` output of `50-compute`.

---

## Resize or remove an EBS volume

The production `web` instance has two extra volumes, `data1` (`/dev/sdf`) and `data2` (`/dev/sdg`).

**First use: format and mount `data1`.** On the instance:

```bash
lsblk                                   # Nitro instances show the volumes as nvme1n1, nvme2n1
sudo mkfs -t xfs /dev/nvme1n1
sudo mkdir -p /data1 && sudo mount /dev/nvme1n1 /data1
```

**Remove `data2`.** Unmount it if it is mounted (`sudo umount /data2`), then delete its entry from `ebs_volumes` and apply `50-compute`. Terraform detaches the volume, then deletes it.

**Extend `data1`.** Raise its size and apply:

```hcl
ebs_volumes = {
  data1 = { size = 20, device = "/dev/sdf" }
}
```

The volume grows online. Then grow the filesystem on the instance:

```bash
sudo xfs_growfs -d /data1
df -h /data1
```

**Backups** happen daily through Data Lifecycle Manager (7 kept, copied to us-west-2). To take one now:

```bash
aws ec2 create-snapshot --volume-id <volume-id> --description "manual before change" \
  --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Project,Value=Marck Enterprise}]'
```

## Restore an earlier version of a file

The assets bucket keeps every version for 75 days.

```bash
BUCKET=<assets_bucket output>
KEY=reports/branch-summary.csv

aws s3api list-object-versions --bucket "$BUCKET" --prefix "$KEY" \
  --query 'Versions[].{Version:VersionId,Modified:LastModified,Latest:IsLatest}' --output table

# Copy the good version over the current one. It becomes the newest version; history is kept.
aws s3api copy-object --bucket "$BUCKET" --key "$KEY" \
  --copy-source "$BUCKET/$KEY?versionId=<good-version-id>"
```

If the file was deleted, removing the delete marker brings it back:

```bash
aws s3api delete-object --bucket "$BUCKET" --key "$KEY" --version-id <delete-marker-version-id>
```

## Send test device events

```bash
STREAM=marck-enterprise-device-events
for i in $(seq 1 20); do
  aws kinesis put-record --stream-name "$STREAM" --partition-key "pos-$i" \
    --cli-binary-format raw-in-base64-out \
    --data "{\"device_id\":\"pos-$i\",\"branch\":\"miami\",\"metric\":\"sale\",\"value\":$i}"
done
```

Within a few seconds a summary appears under `s3://<analytics_bucket>/summaries/`, and the `MarckEnterprise/Devices` metrics show up in CloudWatch.

## Regional failover

Global Accelerator already sends users to the nearest healthy region and stops using an unhealthy one. The web tier needs no action.

Writes need a decision, because Aurora writes go to Virginia:

1. **Virginia is degraded but up:** do nothing. Oregon reads locally and forwards writes.
2. **Virginia is down:** fail the global database over to Oregon.
   ```bash
   aws rds failover-global-cluster --region us-west-2 \
     --global-cluster-identifier marck-enterprise-global \
     --target-db-cluster-identifier arn:aws:rds:us-west-2:<account>:cluster:marck-enterprise-secondary \
     --allow-data-loss
   ```
   Use `switchover-global-cluster` instead (no data loss) when Virginia is still reachable and you are moving on purpose.
3. Update the `writer_host` in the `marck-enterprise/aurora/app` secret if the app reads it.
4. After recovery, run `terraform plan` on `30-data`. Terraform will want to put things back the way the code says; review before applying.

## Roll back a release

CodeDeploy rolls back on its own when a deployment fails its `ValidateService` hook. To roll back a release that passed but is wrong, redeploy the previous revision:

```bash
aws deploy list-deployments --application-name marck-enterprise-web --deployment-group-name production
aws deploy create-deployment --application-name marck-enterprise-web --deployment-group-name production \
  --revision "$(aws deploy get-deployment --deployment-id <previous-good-id> --query 'deploymentInfo.revision' --output json)"
```

Or revert the commit in GitHub; the pipeline ships the revert like any other change.

## Check configuration drift

```bash
aws ssm list-associations --association-filter-list key=AssociationName,value=marck-enterprise-baseline
aws ssm describe-association-executions --association-id <id>
```

To re-apply now instead of waiting for the daily run:

```bash
aws ssm start-associations-once --association-ids <id>
```
