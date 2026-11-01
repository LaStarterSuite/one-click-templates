#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

APP_ROOT=/srv/app

useradd --system --home-dir "$APP_ROOT" --shell /usr/sbin/nologin app
python3 -m venv "$APP_ROOT/venv"
"$APP_ROOT/venv/bin/pip" install --quiet --no-cache-dir -r "$APP_ROOT/requirements.txt"
chown -R app:app "$APP_ROOT"

# The app needs its secret key, which first boot makes, so first boot starts it.
systemctl enable nginx
