"""Unit tests for the Lambda handlers. No AWS access needed: the S3 client is replaced with a fake.

Run from the repository root:  python -m unittest discover -s functions/tests
"""

import base64
import importlib.util
import json
import os
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / name / "handler.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeS3:
    def __init__(self, fail=False):
        self.calls = []
        self.fail = fail

    def put_object(self, **kwargs):
        if self.fail:
            raise RuntimeError("boom")
        self.calls.append(("put_object", kwargs))

    def head_object(self, **kwargs):
        self.calls.append(("head_object", kwargs))
        return {"ContentLength": 12, "ContentType": "text/plain"}

    def put_object_tagging(self, **kwargs):
        self.calls.append(("put_object_tagging", kwargs))


def kinesis_record(payload, seq="1"):
    raw = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
    return {"kinesis": {"data": base64.b64encode(raw).decode(), "sequenceNumber": seq}}


class DeviceTelemetryTest(unittest.TestCase):
    def setUp(self):
        self.mod = load("device_telemetry")
        os.environ["ANALYTICS_BUCKET"] = "test-bucket"

    def test_summarizes_by_branch_and_skips_bad_records(self):
        fake = FakeS3()
        self.mod._s3 = fake
        event = {
            "Records": [
                kinesis_record({"branch": "miami", "device_id": "a", "value": 10}, "1"),
                kinesis_record({"branch": "miami", "device_id": "b", "value": 5}, "2"),
                kinesis_record({"branch": "tampa", "device_id": "c", "value": 1}, "3"),
                kinesis_record(b"not json", "4"),
            ]
        }
        result = self.mod.handler(event, None)

        self.assertEqual(result, {"batchItemFailures": []})
        self.assertEqual(len(fake.calls), 1)
        body = json.loads(fake.calls[0][1]["Body"])
        self.assertEqual(body["branches"]["miami"], {"events": 2, "total": 15.0, "devices": 2})
        self.assertEqual(body["branches"]["tampa"]["events"], 1)

    def test_reports_every_record_when_write_fails(self):
        self.mod._s3 = FakeS3(fail=True)
        event = {"Records": [kinesis_record({"branch": "miami"}, "7"), kinesis_record({"branch": "miami"}, "8")]}
        result = self.mod.handler(event, None)
        self.assertEqual([f["itemIdentifier"] for f in result["batchItemFailures"]], ["7", "8"])


class ObjectCreatedTest(unittest.TestCase):
    def test_tags_each_new_object(self):
        mod = load("s3_object_created")
        fake = FakeS3()
        mod._s3 = fake
        event = {
            "Records": [
                {
                    "eventName": "ObjectCreated:Put",
                    "s3": {"bucket": {"name": "assets"}, "object": {"key": "reports/q3+summary.pdf", "versionId": "v1"}},
                }
            ]
        }
        result = mod.handler(event, None)

        self.assertEqual(result["handled"], ["reports/q3 summary.pdf"])
        tagging = [c for c in fake.calls if c[0] == "put_object_tagging"][0][1]
        self.assertEqual(tagging["VersionId"], "v1")
        self.assertEqual(tagging["Tagging"]["TagSet"], [{"Key": "processed", "Value": "true"}])


if __name__ == "__main__":
    unittest.main()
