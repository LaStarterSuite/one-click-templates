# Shared helpers for first-boot scripts. Source this file; do not run it.

ONE_CLICK_INPUTS=/etc/one-click/inputs.env
# The application's own environment: its unit loads it, and only root and the app group read it.
ONE_CLICK_CREDENTIALS=/etc/one-click/app.env
ONE_CLICK_READY=/var/lib/one-click/ready
METADATA_URL=http://169.254.169.254/latest

# Print one Atlas metadata value, such as public-ipv4 or local-hostname.
metadata() {
	local token
	token=$(curl -fsS -X PUT -H "X-metadata-token-ttl-seconds: 60" "$METADATA_URL/api/token")
	curl -fsS -H "X-metadata-token: $token" "$METADATA_URL/meta-data/$1"
}

# Write the nginx site and reload nginx. The regional proxy serves HTTPS in front of it.
configure_nginx() {
	cat > /etc/nginx/sites-available/default
	nginx -t
	systemctl reload nginx
}

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

# Add one variable to the application's environment. Templates run the app as group `app`.
# The value is double-quoted with systemd's escapes, so any secret reads back as written.
save_credential() {
	[ -f "$ONE_CLICK_CREDENTIALS" ] || install -m 0640 -o root -g app /dev/null "$ONE_CLICK_CREDENTIALS"
	local value=${2//\\/\\\\}
	value=${value//\"/\\\"}
	printf '%s="%s"\n' "$1" "$value" >> "$ONE_CLICK_CREDENTIALS"
}

# Tell Central the application answers, with the token it put in the metadata at creation.
# A VM launched outside Central has no token and skips the report.
report_ready() {
	local central endpoint token status
	central=$(metadata attributes/one-click-central 2>/dev/null) || return 0
	endpoint=$(jq -r .endpoint <<< "$central")
	token=$(jq -r .token <<< "$central")

	# Central answers 404 until the region has reported the server, so keep sending.
	for _ in $(seq 1 30); do
		status=$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
			-H "X-Template-Token: $token" \
			"$endpoint/api/method/central.api.servers.report_template_ready") || status=000
		case $status in
			200) return 0 ;;
			401 | 403)
				echo "Central refused the ready report (HTTP $status)." >&2
				return 1
				;;
		esac
		sleep 10
	done
	echo "Central did not accept the ready report (HTTP $status)." >&2
	return 1
}

# Record that first boot finished, then tell Central. A failed report leaves the app running.
mark_ready() {
	install -d "$(dirname "$ONE_CLICK_READY")"
	date -u +%FT%TZ > "$ONE_CLICK_READY"
	report_ready || true
}
