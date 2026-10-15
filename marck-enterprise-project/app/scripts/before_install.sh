#!/bin/bash
# Make sure the web stack exists (it does on the golden AMI and after user data) and clear the old release.
set -euo pipefail

if ! command -v httpd >/dev/null 2>&1; then
  dnf install -y httpd php php-cli php-mysqlnd php-fpm php-json
fi

mkdir -p /var/www/html
find /var/www/html -mindepth 1 -delete
