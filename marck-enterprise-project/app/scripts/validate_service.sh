#!/bin/bash
# Fail the deployment (and trigger rollback) if the instance does not serve the health page.
set -euo pipefail

for attempt in $(seq 1 10); do
  if curl -fsS --max-time 3 http://localhost/health.php | grep -q '^ok$'; then
    echo "Health check passed on attempt $attempt"
    exit 0
  fi
  sleep 3
done

echo "Health check failed" >&2
exit 1
