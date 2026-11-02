#!/bin/bash
set -euo pipefail

# Settings that differ per server go in one-click.conf, which first boot writes.
# Redis keeps the last value of a setting, so the include goes at the end.
echo "include /etc/redis/one-click.conf" >> /etc/redis/redis.conf
systemctl enable redis-server
