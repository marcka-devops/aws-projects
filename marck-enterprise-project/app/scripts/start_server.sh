#!/bin/bash
set -euo pipefail

# The bundle carries deployment-only files; keep them out of the web root.
rm -rf /var/www/html/scripts /var/www/html/appspec.yml

systemctl enable php-fpm httpd
systemctl restart php-fpm
systemctl restart httpd
