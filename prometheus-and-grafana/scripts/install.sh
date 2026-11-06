#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

PROMETHEUS_VERSION=3.15.1
declare -A PROMETHEUS_SHA256=(
	[amd64]=6a726885328ad9efebbf36e876ce2fb6225468a71fd1e7ce3ba666d5f4d97a84
	[arm64]=ceb6d21493c37ca0b4513b147642797c68cf39a0f50a444d50e1e80c74f21b26
)
GRAFANA_VERSION=13.2.5
declare -A GRAFANA_SHA256=(
	[amd64]=3c8d7874f2e14120044c3f131a47c25bd9412e449f9037e298bc6419630c73b7
	[arm64]=b0e1fededdcbb3860645298c0c2e316752f832ec6bbcaac10452e46b09e60ac4
)

arch=$(dpkg --print-architecture)
if [ -z "${PROMETHEUS_SHA256[$arch]:-}" ] || [ -z "${GRAFANA_SHA256[$arch]:-}" ]; then
	echo "No checksum here for $arch." >&2
	exit 1
fi
cd "$(mktemp -d)"

prometheus_archive=prometheus-$PROMETHEUS_VERSION.linux-$arch.tar.gz
curl -fsSLO "https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/$prometheus_archive"
echo "${PROMETHEUS_SHA256[$arch]}  $prometheus_archive" | sha256sum -c -
tar -xzf "$prometheus_archive" --strip-components=1
install -m 0755 prometheus promtool /usr/local/bin/

useradd --system --no-create-home --shell /usr/sbin/nologin prometheus
install -d -o prometheus -g prometheus /var/lib/prometheus

grafana_package=grafana_${GRAFANA_VERSION}_$arch.deb
curl -fsSLO "https://dl.grafana.com/oss/release/$grafana_package"
echo "${GRAFANA_SHA256[$arch]}  $grafana_package" | sha256sum -c -
apt-get install -y --no-install-recommends "./$grafana_package"
# Grafana creates its admin user and secret key on first start, which must happen on each VM.
rm -f /var/lib/grafana/grafana.db
install -d -o root -g grafana /etc/grafana/provisioning/datasources

# conf.d/one-click.conf takes port 80 in place of the default site.
rm -f /etc/nginx/sites-enabled/default
nginx -t

systemctl daemon-reload
systemctl enable prometheus grafana-server nginx
