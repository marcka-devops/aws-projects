"""Kinesis consumer for branch device telemetry.

Each record is JSON such as:
    {"device_id": "pos-114", "branch": "miami", "metric": "sale", "value": 42.5, "ts": "2026-10-14T13:05:00Z"}

For every batch the function
  * writes one per-branch summary to s3://$ANALYTICS_BUCKET/summaries/YYYY/MM/DD/HH/<request id>.json
  * prints CloudWatch Embedded Metric Format lines, which become metrics without PutMetricData calls
"""

import base64
import json
import os
import time
import uuid
from collections import defaultdict
from datetime import datetime, timezone

_s3 = None


def s3_client():
    global _s3
    if _s3 is None:
        import boto3

        _s3 = boto3.client("s3")
    return _s3


def parse(record):
    """Return the decoded event, or None if the payload is not usable JSON."""
    try:
        data = json.loads(base64.b64decode(record["kinesis"]["data"]))
    except (KeyError, ValueError, TypeError):
        return None
    if not isinstance(data, dict) or "branch" not in data:
        return None
    return data


def summarize(events):
    summary = defaultdict(lambda: {"events": 0, "total": 0.0, "devices": set()})
    for event in events:
        branch = summary[str(event["branch"])]
        branch["events"] += 1
        branch["total"] += float(event.get("value") or 0)
        if "device_id" in event:
            branch["devices"].add(str(event["device_id"]))
    return {
        name: {"events": s["events"], "total": round(s["total"], 2), "devices": len(s["devices"])}
        for name, s in summary.items()
    }


def emf_line(namespace, branch, stats):
    return json.dumps(
        {
            "_aws": {
                "Timestamp": int(time.time() * 1000),
                "CloudWatchMetrics": [
                    {
                        "Namespace": namespace,
                        "Dimensions": [["Branch"]],
                        "Metrics": [
                            {"Name": "Events", "Unit": "Count"},
                            {"Name": "ActiveDevices", "Unit": "Count"},
                        ],
                    }
                ],
            },
            "Branch": branch,
            "Events": stats["events"],
            "ActiveDevices": stats["devices"],
        }
    )


def handler(event, context):
    records = event.get("Records", [])
    good, invalid = [], 0
    for record in records:
        parsed = parse(record)
        if parsed is None:
            invalid += 1
        else:
            good.append(parsed)

    summary = summarize(good)
    now = datetime.now(timezone.utc)
    request_id = getattr(context, "aws_request_id", None) or str(uuid.uuid4())
    key = f"summaries/{now:%Y/%m/%d/%H}/{request_id}.json"

    if summary:
        try:
            s3_client().put_object(
                Bucket=os.environ["ANALYTICS_BUCKET"],
                Key=key,
                Body=json.dumps({"generated_at": now.isoformat(), "branches": summary}).encode(),
                ContentType="application/json",
            )
        except Exception as exc:  # retry the whole batch
            print(json.dumps({"level": "error", "message": "summary write failed", "error": str(exc)}))
            return {
                "batchItemFailures": [
                    {"itemIdentifier": r["kinesis"]["sequenceNumber"]} for r in records if "kinesis" in r
                ]
            }

    namespace = os.environ.get("METRIC_NAMESPACE", "MarckEnterprise/Devices")
    for branch, stats in summary.items():
        print(emf_line(namespace, branch, stats))

    print(json.dumps({"level": "info", "records": len(records), "invalid": invalid, "branches": len(summary), "key": key}))
    # Invalid records are logged and dropped, never retried.
    return {"batchItemFailures": []}
