#!/bin/bash
set -euxo pipefail

dnf install -y ruby wget
cd /tmp
wget -q "https://aws-codedeploy-${region}.s3.${region}.amazonaws.com/latest/install"
chmod +x ./install
./install auto || true

if [ -n "${fsx_dns}" ]; then
  dnf install -y lustre-client || true
  mkdir -p /mnt/fsx
  mount -t lustre "${fsx_dns}@tcp:/${fsx_mount}" /mnt/fsx || true
  echo "${fsx_dns}@tcp:/${fsx_mount} /mnt/fsx lustre defaults,_netdev 0 0" >> /etc/fstab || true
fi
