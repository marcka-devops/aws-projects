import json


def handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        print(json.dumps({"bucket": bucket, "key": key}))
    return {"ok": True}
