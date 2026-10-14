"""Runs on every s3:ObjectCreated:* event in the assets bucket.

It records what arrived (key, size, type, version) in the logs and tags the object
with processed=true so the team can see which uploads the function has handled.
Tagging does not raise a new ObjectCreated event, so the function never triggers itself.
"""

import json
from urllib.parse import unquote_plus

_s3 = None


def s3_client():
    global _s3
    if _s3 is None:
        import boto3

        _s3 = boto3.client("s3")
    return _s3


def handler(event, context):
    handled = []
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = unquote_plus(record["s3"]["object"]["key"])
        version = record["s3"]["object"].get("versionId")

        extra = {"VersionId": version} if version else {}
        head = s3_client().head_object(Bucket=bucket, Key=key, **extra)
        s3_client().put_object_tagging(
            Bucket=bucket,
            Key=key,
            Tagging={"TagSet": [{"Key": "processed", "Value": "true"}]},
            **extra,
        )

        info = {
            "event": record.get("eventName"),
            "bucket": bucket,
            "key": key,
            "version": version,
            "size": head.get("ContentLength"),
            "content_type": head.get("ContentType"),
        }
        print(json.dumps(info))
        handled.append(key)

    return {"handled": handled}
