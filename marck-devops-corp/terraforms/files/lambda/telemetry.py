import base64
import os

import boto3


def handler(event, context):
    bucket = os.environ["TELEMETRY_BUCKET"]
    client = boto3.client("s3")
    for record in event.get("Records", []):
        payload = base64.b64decode(record["kinesis"]["data"])
        sequence = record["kinesis"]["sequenceNumber"]
        client.put_object(
            Bucket=bucket,
            Key=f"raw/{sequence}.json",
            Body=payload,
            ContentType="application/json",
        )
    return {"archived": len(event.get("Records", []))}
