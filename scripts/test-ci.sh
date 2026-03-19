#!/usr/bin/env bash

set -euo pipefail

PATH="${HOME}/.local/bin:/usr/local/bin:/opt/homebrew/bin:${PATH}"
export PATH

section() {
	printf '\n== %s ==\n' "$1"
}

ok() {
	printf '[OK] %s\n' "$1"
}

fail() {
	printf '[FAIL] %s\n' "$1"
	printf '       %s\n' "$2"
	exit 1
}

check_direct() {
	local label="$1"
	shift

	local output
	if output="$("$@" 2>&1)"; then
		ok "$label"
		return 0
	fi

	fail "$label" "$output"
}

check_mise() {
	local label="$1"
	shift

	local output
	if output="$(mise exec -- "$@" 2>&1)"; then
		ok "$label"
		return 0
	fi

	fail "$label" "$output"
}

check_port_selector() {
	local output

	if ! output="$(mise exec -- port-selector --name ci-smoke 2>&1)"; then
		fail "port-selector returns a free port" "$output"
	fi

	if ! printf '%s' "$output" | tr -d '[:space:]' | grep -Eq '^[0-9]+$'; then
		fail "port-selector returns a free port" "$output"
	fi

	ok "port-selector returns a free port"
	mise exec -- port-selector --forget --name ci-smoke >/dev/null 2>&1 || true
}

section "Bootstrap"
check_direct "mise installed" mise --version

section "Core toolchain"
check_mise "direnv installed" direnv version
check_mise "gh installed" gh --version
check_mise "himalaya installed" himalaya --version
check_mise "gitleaks installed" gitleaks version
check_mise "jq installed" jq --version
check_mise "node installed" node --version
check_mise "npm installed" npm --version
check_mise "npx installed" npx --version
check_port_selector
check_mise "ruby installed" ruby --version
check_mise "tmux installed" tmux -V
check_mise "yarn installed" yarn --version
check_mise "zellij installed" zellij --version

section "Agent CLIs"
check_mise "claude installed" claude --version
check_mise "codex installed" codex --version
check_mise "playwright-cli installed" playwright-cli --version
check_mise "tgcli installed" tgcli --help
check_mise "gws installed" gws --help

printf '\nCI smoke checks passed.\n'
