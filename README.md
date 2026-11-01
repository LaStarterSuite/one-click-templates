# Frappe Cloud One-Click Templates

Each folder here describes one application that users can launch from Central as a ready-to-use virtual machine. Cargo builds every merged template into an Atlas image, and renders the template's cloud-init user data when a user launches it.

## How a template becomes a running VM

1. **Build (Cargo, on merge).** Cargo boots a temporary Atlas VM and, over SSH as root:
   1. installs the apt packages from `common/config/packages.txt` and `<name>/config/packages.txt`;
   2. copies each `build.files` source to its destination, `common`'s first and then the template's;
   3. runs `<name>/scripts/*.sh`, then `common/scripts/*.sh`, each in name order.

   Then it stops the VM and Atlas snapshots its disk. Nothing secret or specific to one VM may be created at build time.
2. **Launch (Central → Cargo → Atlas).** Central asks Cargo for the template's inputs and sends the answers back. Cargo validates them and returns user data that only writes them to `/etc/one-click/inputs.env`.
3. **First boot (cloud-init).** The VM has a new instance ID, so cloud-init runs `/var/lib/cloud/scripts/per-instance/001_onboot` once. It reads the inputs, generates secrets, configures the service, and writes `/var/lib/one-click/ready`. Reboots do not run it again.

## Layout

```
common/                         Shared by every template
  config/packages.txt           Base apt packages
  config/template.yaml          build.files copied before a template's own files
  src/
  scripts/900-cleanup.sh        Runs after every template's scripts; makes the disk safe to snapshot
_template/                      Copy this to start a new template
<name>/
  config/template.yaml          Manifest (below)
  config/packages.txt           apt packages, one per line; # comments allowed
  src/                          Files listed in build.files; mirroring the VM's paths keeps it readable
  src/var/lib/cloud/scripts/per-instance/001_onboot   First-boot setup, executable
  scripts/*.sh                  Build scripts, run in name order
```

## template.yaml

```yaml
name: redis                     # Folder name; lowercase letters, digits and hyphens
title: Redis
description: One line shown in Central.
categories: [database]
maintainers:
  - github: frappe
base_image:                     # Atlas system image tags Cargo boots the build on
  os: Ubuntu
  os_version: "24.04"
  minimal: true
minimum_size:                   # Central hides smaller plans and refuses them at creation
  cpu_millicores: 500
  memory_mib: 512
  disk_mib: 5120
ports:                          # The ports the service listens on, for the user; Central opens none
  - { port: 6379, protocol: tcp }
build:
  files:                        # Copied in order; a folder source ends in / and its contents go into destination
    - { source: src/etc/, destination: /etc/ }    # source inside src/; destination under /etc, /opt, /srv, /usr or /var
    - { source: src/var/, destination: /var/ }
inputs:                         # Asked in Central, validated by Cargo
  - name: redis_password        # Becomes REDIS_PASSWORD in inputs.env
    label: Password
    type: password              # string | email | domain | password
    generate: true              # Left out when blank; 001_onboot makes one on the VM
  - name: database
    label: Database
    type: string
    required: false
    max_length: 64
    pattern: "[a-z][a-z0-9_]*"
```

Input rules Cargo enforces: `name` matches `^[a-z][a-z0-9_]*$`; `string` accepts an optional `pattern` and `max_length` (default 255); `domain` and `email` are checked by type; `password` is at least 12 characters. Values never reach a shell unquoted: Cargo writes them as `KEY='value'` lines with shell quoting.

## Rules for build scripts

- Run as root, non-interactively, with `set -euo pipefail`. A non-zero exit fails the build.
- Pin every version so a rebuild is reproducible, and verify direct downloads against a published checksum.
- Leave services enabled but generic: no passwords, keys, hostnames or domains. Create them in `001_onboot`.
- Packages are installed and files copied before the scripts run, so a script can rely on both.
- `common/scripts/900-cleanup.sh` runs last and wipes the build SSH key, SSH host keys, machine ID, cloud-init state, logs and shell history.

## Rules for 001_onboot

- Inputs are optional: the VM may be launched without user data. Load `/etc/one-click/inputs.env` only if it exists, and give every input a default or generate it with `openssl rand`.
- Source `/usr/local/lib/one-click/lib.sh` for `metadata`, `wait_for`, `save_credential` and `mark_ready`.
- Listen on every IPv4 and IPv6 address, and require a password. Without a public address the server is reachable only on the region's private network, which other servers share.
- Generate secrets such as a password with `openssl rand`. Store them, and every setting the user needs to connect, with `save_credential KEY value`. It appends to `/etc/one-click/app.env` (mode 0600, owner `root`), which the user reads over SSH. Secrets never leave the VM.
- Finish with `mark_ready`. Output goes to `/var/log/cloud-init-output.log`.

See [CONTRIBUTING.md](CONTRIBUTING.md) to add a template.
