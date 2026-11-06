# Frappe Cloud One-Click Apps

Each folder here describes one service that users can launch from Central as a ready-to-use virtual machine. Cargo builds every merged app into an Atlas image, and renders the app's cloud-init user data when a user launches it.

An app is for a service whose setup changes little from one user to the next, such as a database or a cache. The user picks a size and answers a few inputs, and the server is ready. An application framework such as Flask, Django or React is not an app here: its setup depends on the user's own code, so it belongs to push-and-deploy, not here.

## Apps

| App | Port | Inputs | Settings in `/etc/one-click/app.env` |
| --- | --- | --- | --- |
| [Redis](redis/) | 6379 | Password | `REDIS_PASSWORD` |
| [MariaDB](mariadb/) | 3306 | Admin password, database | `MARIADB_USER` (`admin`), `MARIADB_PASSWORD`, `MARIADB_DATABASE` |
| [Prometheus and Grafana](prometheus-and-grafana/) | 80, 9090, 3000 | Prometheus password, Grafana password | `PROMETHEUS_USER` (`admin`), `PROMETHEUS_PASSWORD`, `GRAFANA_USER` (`admin`), `GRAFANA_PASSWORD` |

An input that is not `required` may be left blank, and the server generates its value at first boot.

## Connecting to an app server

Central creates an app server as a normal server. It routes no web address to it and opens no port for it.

- The service listens on every IPv4 and IPv6 address and requires a password.
- Without a public address, the server is reachable only on the region's private network, at its private IPv6 address. Other servers in the region can reach it there.
- To connect from outside the region, give the server a public address. If the server's firewall is on, add a rule for the service's port.
- Read the password over SSH: `sudo cat /etc/one-click/app.env`. The login message says whether first boot has finished.

For example, from another server in the region:

```sh
redis-cli -h <private IPv6 address> -a "$REDIS_PASSWORD" ping
mariadb -h <private IPv6 address> -u admin -p
```

## How an app becomes a running VM

1. **Build (Cargo, on merge).** Cargo boots a temporary Atlas VM and, over SSH as root:
   1. installs the apt packages from `common/config/packages.txt` and `<name>/config/packages.txt`;
   2. copies each `build.files` source to its destination, `common`'s first and then the app's;
   3. runs `<name>/scripts/*.sh`, then `common/scripts/*.sh`, each in name order.

   Then it stops the VM and Atlas snapshots its disk. Nothing secret or specific to one VM may be created at build time.
2. **Launch (Central → Cargo → Atlas).** Central asks Cargo for the app's inputs and sends the answers back. Cargo validates them and returns user data that only writes them to `/etc/one-click/inputs.env`.
3. **First boot (cloud-init).** The VM has a new instance ID, so cloud-init runs `/var/lib/cloud/scripts/per-instance/001_onboot` once. It reads the inputs, generates secrets, configures the service, and writes `/var/lib/one-click/ready`. Reboots do not run it again.

## Layout

```
common/                         Shared by every app
  config/packages.txt           Base apt packages
  config/template.yaml          build.files copied before an app's own files
  src/
  scripts/900-cleanup.sh        Runs after every app's scripts; makes the disk safe to snapshot
_template/                      Copy this to start a new app
<name>/
  config/template.yaml          Manifest (below)
  config/packages.txt           apt packages, one per line; # comments allowed
  config/logo.svg               Optional logo shown in Central
  src/                          Files listed in build.files; mirroring the VM's paths keeps it readable
  src/var/lib/cloud/scripts/per-instance/001_onboot   First-boot setup, executable
  scripts/*.sh                  Build scripts, run in name order
```

## template.yaml

```yaml
name: mariadb                   # Folder name; lowercase letters, digits and hyphens
title: MariaDB
description: One line shown in Central.
logo: config/logo.svg           # Optional SVG inside the app folder, at most 32 KiB; Central shows a generic logo without it
maintainers:
  - github: frappe
base_image:                     # Atlas system image tags Cargo boots the build on
  os: Ubuntu
  os_version: "24.04"
  minimal: true
minimum_size:                   # Central hides smaller plans and refuses them at creation
  cpu_millicores: 1000
  memory_mib: 1024
  disk_mib: 10240
ports:                          # The ports the service listens on, for the user; Central opens none
  - { port: 3306, protocol: tcp }
build:
  files:                        # Copied in order; a folder source ends in / and its contents go into destination
    - { source: src/etc/, destination: /etc/ }    # source inside src/; destination under /etc, /opt, /srv, /usr or /var
    - { source: src/var/, destination: /var/ }
inputs:                         # Asked and validated in Central
  - name: mariadb_password      # Becomes MARIADB_PASSWORD in inputs.env
    label: Admin password
    type: password              # string | email | domain | password; optional, so 001_onboot makes one when blank
  - name: mariadb_database
    label: Database
    type: string
    required: false
    max_length: 64
    pattern: "[a-z][a-z0-9_]*"  # Checked by Central; 001_onboot checks it again before it reaches SQL
```

An app with a `site_name` input gets a web address: Central routes `<site_name>.<region zone>` to the server's port 80 through the regional proxy, which ends HTTPS, and adds the full name as `SITE_DOMAIN` to `inputs.env`.

Input rules Central enforces: `name` matches `^[a-z][a-z0-9_]*$`; every input accepts an optional `pattern` and `max_length` (default 255); `domain` and `email` are checked by type; `password` must not be easy to guess. A blank optional input is left out. Values never reach a shell unquoted: Central writes them as `KEY='value'` lines with shell quoting.

## Rules for build scripts

- Run as root, non-interactively, with `set -euo pipefail`. A non-zero exit fails the build.
- Pin every version so a rebuild is reproducible, and verify direct downloads against a published checksum.
- Leave services enabled but generic: no passwords, keys, hostnames or domains. Create them in `001_onboot`.
- Packages are installed and files copied before the scripts run, so a script can rely on both.
- `common/scripts/900-cleanup.sh` runs last and wipes the build SSH key, SSH host keys, machine ID, cloud-init state, logs and shell history.

## Rules for 001_onboot

- Inputs are optional: the VM may be launched without user data. Load `/etc/one-click/inputs.env` only if it exists, and give every input a default or generate it with `openssl rand`.
- Source `/usr/local/lib/one-click/lib.sh` for `wait_for`, `save_credential` and `mark_ready`.
- Listen on every IPv4 and IPv6 address, and require a password. Without a public address the server is reachable only on the region's private network, which other servers share.
- Generate secrets such as a password with `openssl rand`. Store them, and every setting the user needs to connect, with `save_credential KEY value`. It appends to `/etc/one-click/app.env` (mode 0600, owner `root`), which the user reads over SSH. Secrets never leave the VM.
- Finish with `mark_ready`. Output goes to `/var/log/cloud-init-output.log`.

See [CONTRIBUTING.md](CONTRIBUTING.md) to add an app.
