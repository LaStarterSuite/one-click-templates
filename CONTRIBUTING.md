# Contributing a Template

1. Copy `_template/` to a folder named after the application, and set `name` in `config/template.yaml` to match.
2. List apt packages in `config/packages.txt`, put the files the VM needs under `src/` and list each source and destination under `build.files` in `config/template.yaml`, write the build in `scripts/`, and the per-VM setup in `src/var/lib/cloud/scripts/per-instance/001_onboot` (executable: `git add --chmod=+x`).
3. Declare every value the user may provide under `inputs`, with a default or `generate: true` in `001_onboot` for each.
4. Test the build on a fresh Ubuntu VM: install `common/config/packages.txt` and your `config/packages.txt`, copy each `build.files` entry of `common` and then yours, run your scripts in name order, then write `/etc/one-click/inputs.env` by hand and run `001_onboot`.
5. Open a pull request with what the template installs, which versions, and how you tested it.

A pull request is reviewed for:

- No secret, key or VM-specific value created at build time.
- Downloads pinned to a version and verified with a checksum.
- No user input interpolated into a shell command or config without quoting.
- `001_onboot` ending in `mark_ready`, and the health check answering after it.
- A maintainer listed in `config/template.yaml` who will answer issues about the template.

Merging builds the image in Cargo. A template whose build fails twice in a row is hidden from Central until fixed.
