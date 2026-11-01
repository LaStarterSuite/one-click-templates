#!/bin/bash
# Runs after every application script. Removes everything that must differ between VMs launched from the image.
set -euo pipefail

apt-get -qqy autoremove --purge
apt-get -qqy clean
rm -rf /var/lib/apt/lists/*

rm -f /etc/one-click/inputs.env /etc/one-click/app.env /var/lib/one-click/ready

# The build machine's key would otherwise open every VM. cloud-init adds the user's keys at boot.
rm -f /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys
rm -f /etc/ssh/ssh_host_*
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Not `cloud-init clean`: it deletes /var/lib/cloud/scripts, which holds each template's 001_onboot.
find /var/lib/cloud -mindepth 1 -maxdepth 1 ! -name scripts ! -name seed -exec rm -rf {} +
rm -f /var/log/cloud-init*.log
find /var/log -type f -exec truncate -s 0 {} +
rm -rf /tmp/* /var/tmp/*
rm -f /root/.bash_history /home/*/.bash_history

sync
