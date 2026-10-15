# Lambda functions

| Function | Trigger | What it does | Deployed by |
| --- | --- | --- | --- |
| [`device_telemetry`](device_telemetry/handler.py) | Kinesis stream `marck-enterprise-device-events` | Summarizes events per branch, writes the summary to S3, emits CloudWatch metrics (Embedded Metric Format) | `infra/stacks/30-data/streaming.tf` |
| [`s3_object_created`](s3_object_created/handler.py) | `s3:ObjectCreated:*` on the assets bucket | Logs what arrived and tags the object `processed=true` | `infra/stacks/40-storage/assets.tf` |

Both use only the Python standard library and boto3 (included in the Lambda runtime), so there is nothing to install. Terraform zips each folder.

## Tests

```bash
python -m unittest discover -s functions/tests -v
```

The tests replace the S3 client with a fake, so they need no AWS access.
