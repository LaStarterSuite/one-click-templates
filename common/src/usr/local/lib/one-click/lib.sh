# Shared helpers for first-boot scripts. Source this file; do not run it.

ONE_CLICK_INPUTS=/etc/one-click/inputs.env
# The service's settings and generated secrets, for the user to read over SSH.
ONE_CLICK_CREDENTIALS=/etc/one-click/app.env
ONE_CLICK_READY=/var/lib/one-click/ready

# Run a command until it succeeds, for at most a given number of seconds.
wait_for() {
	local seconds=$1
	shift
	for _ in $(seq 1 "$seconds"); do
		"$@" > /dev/null 2>&1 && return 0
		sleep 1
	done
	echo "Timed out waiting for: $*" >&2
	return 1
}

# Add one setting to the server's settings file, which only root reads.
# The value is double-quoted with systemd's escapes, so any secret reads back as written.
save_credential() {
	[ -f "$ONE_CLICK_CREDENTIALS" ] || install -m 0600 -o root -g root /dev/null "$ONE_CLICK_CREDENTIALS"
	local value=${2//\\/\\\\}
	value=${value//\"/\\\"}
	printf '%s="%s"\n' "$1" "$value" >> "$ONE_CLICK_CREDENTIALS"
}

# Record that first boot finished. The motd reads it.
mark_ready() {
	install -d "$(dirname "$ONE_CLICK_READY")"
	date -u +%FT%TZ > "$ONE_CLICK_READY"
}
