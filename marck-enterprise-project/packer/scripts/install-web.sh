#!/bin/bash
# Bake the web stack into the golden AMI so instances boot ready to serve.
set -euo pipefail

dnf -y update
dnf install -y httpd php php-cli php-mysqlnd php-fpm php-json ruby wget nfs-utils amazon-cloudwatch-agent

# CodeDeploy agent. The installer works in any region; the agent finds its region at runtime.
cd /tmp
wget -q "https://aws-codedeploy-${AWS_REGION}.s3.${AWS_REGION}.amazonaws.com/latest/install"
chmod +x ./install
./install auto
systemctl enable codedeploy-agent

mkdir -p /var/www/html
printf '<?php http_response_code(200); echo "ok"; ?>\n' > /var/www/html/health.php
systemctl enable php-fpm httpd

# Leave no build-time state in the image.
dnf clean all
rm -f /tmp/install
