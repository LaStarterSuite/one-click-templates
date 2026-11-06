#!/bin/bash
# Sends this server's metrics to Prometheus with Grafana Alloy. Run it as root on Ubuntu or Debian:
#   curl -fsSL https://<site>/connect.sh | sudo PUSH_PASSWORD=<push password> bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# First boot of the monitoring server writes its own address here.
PUSH_URL=${PUSH_URL:-__PUSH_URL__}
PUSH_USER=${PUSH_USER:-push}
: "${PUSH_PASSWORD:?Set PUSH_PASSWORD to the push password in /etc/one-click/app.env of the monitoring server.}"
if [[ $PUSH_URL != https://* ]]; then
	echo "Set PUSH_URL to https://<site>/prometheus/api/v1/write." >&2
	exit 1
fi

ALLOY_VERSION=1.21.3
declare -A ALLOY_SHA256=(
	[amd64]=dbbd705de8ab37dec0cbd6361a3fc7e754d6b2854b57ce672a83e6366199ba73
	[arm64]=5e33ee3e0a62dd23564bf98fb8620ef537f870b1750e76866af5c98c0f5229e3
)

arch=$(dpkg --print-architecture)
if [ -z "${ALLOY_SHA256[$arch]:-}" ]; then
	echo "No checksum here for $arch." >&2
	exit 1
fi
cd "$(mktemp -d)"
package=alloy-$ALLOY_VERSION-1.$arch.deb
curl -fsSLO "https://github.com/grafana/alloy/releases/download/v$ALLOY_VERSION/$package"
echo "${ALLOY_SHA256[$arch]}  $package" | sha256sum -c -
apt-get install -y --no-install-recommends "./$package"

install -m 0640 -o root -g alloy /dev/null /etc/alloy/push_password
printf '%s' "$PUSH_PASSWORD" > /etc/alloy/push_password

cat > /etc/alloy/config.alloy <<CONF
prometheus.exporter.unix "node" { }

prometheus.scrape "node" {
  targets         = prometheus.exporter.unix.node.targets
  scrape_interval = "15s"
  forward_to      = [prometheus.relabel.instance.receiver]
}

// Each server shows up by its hostname.
prometheus.relabel "instance" {
  forward_to = [prometheus.remote_write.monitoring.receiver]
  rule {
    target_label = "instance"
    replacement  = constants.hostname
  }
}

prometheus.remote_write "monitoring" {
  endpoint {
    url = "$PUSH_URL"
    basic_auth {
      username      = "$PUSH_USER"
      password_file = "/etc/alloy/push_password"
    }
  }
}
CONF

systemctl enable alloy
systemctl restart alloy
echo "Alloy sends this server's metrics to $PUSH_URL as $(hostname)."
