#!/usr/bin/env bash
#
# Public bootstrap: creates an SSH deploy key on the server, verifies GitHub access,
# clones the private cronwork-server-setup repository, then runs install.sh.
#
# Example:
#   curl -fsSL https://raw.githubusercontent.com/doguab/cronwork-bootstrap-public/main/bootstrap.sh | bash
# or:
#   wget -qO- ... | bash
#
# Optional environment variables:
#   PRIVATE_REPO_SSH  — default: git@github.com:doguab/cronwork-server-setup.git
#   CLONE_DIR         — default: /opt/cronwork-server-setup (root) or ~/cronwork-server-setup
#
set -euo pipefail

PRIVATE_REPO_SSH="${PRIVATE_REPO_SSH:-git@github.com:doguab/cronwork-server-setup.git}"
KEY_NAME="cronwork_github_ed25519"
KEY_FILE="${HOME}/.ssh/${KEY_NAME}"

GITHUB_DEPLOY_KEY_URL="${GITHUB_DEPLOY_KEY_URL:-https://github.com/doguab/cronwork-server-setup/settings/keys}"

die() {
	echo "Error: $*" >&2
	exit 1
}

require_root() {
	if [ "${EUID:-$(id -u)}" -ne 0 ]; then
		die "Must run as root. Example: curl -fsSL https://raw.githubusercontent.com/doguab/cronwork-bootstrap-public/main/bootstrap.sh | sudo bash"
	fi
}

ensure_packages_debian() {
	if command -v apt-get >/dev/null 2>&1; then
		export DEBIAN_FRONTEND=noninteractive
		apt-get update -qq
		apt-get install -y --no-install-recommends git openssh-client curl ca-certificates
	fi
}

ensure_ssh_dir() {
	mkdir -p "${HOME}/.ssh"
	chmod 700 "${HOME}/.ssh"
}

# Zaten private repoya erişim varsa anahtar üretmeden devam et
try_repo_access_already_ok() {
	unset GIT_SSH_COMMAND 2>/dev/null || true

	# 1) Var olan deploy key dosyası (cronwork_github_ed25519)
	if [ -f "$KEY_FILE" ]; then
		export GIT_SSH_COMMAND="ssh -i ${KEY_FILE} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
		if git ls-remote "$PRIVATE_REPO_SSH" HEAD >/dev/null 2>&1; then
			echo "OK: Private repoya zaten erişim var ($KEY_FILE). Deploy key adımı atlanıyor."
			return 0
		fi
		unset GIT_SSH_COMMAND
	fi

	# 2) ~/.ssh/config, ssh-agent veya hesap anahtarı (GIT_SSH_COMMAND olmadan)
	if ( unset GIT_SSH_COMMAND; git ls-remote "$PRIVATE_REPO_SSH" HEAD >/dev/null 2>&1 ); then
		echo "OK: Mevcut SSH yapılandırması ile private repoya erişim var. Deploy key adımı atlanıyor."
		unset GIT_SSH_COMMAND
		return 0
	fi

	return 1
}

generate_key_if_needed() {
	if [ -f "$KEY_FILE" ]; then
		echo "Using existing key: $KEY_FILE"
		return 0
	fi
	echo "Generating new SSH key: $KEY_FILE"
	ssh-keygen -t ed25519 -a 100 -f "$KEY_FILE" -N "" -C "cronwork-deploy-$(hostname -s 2>/dev/null || echo server)-$(date +%Y%m%d)"
	chmod 600 "$KEY_FILE" "${KEY_FILE}.pub"
}

print_instructions() {
	local pubkey
	pubkey="$(cat "${KEY_FILE}.pub")"
	echo ""
	echo "═══════════════════════════════════════════════════════════════════"
	echo "  1) Copy the entire PUBLIC key below (single line):"
	echo "═══════════════════════════════════════════════════════════════════"
	echo ""
	echo "$pubkey"
	echo ""
	echo "═══════════════════════════════════════════════════════════════════"
	echo "  2) Add it as a deploy key to this private repository on GitHub:"
	echo "      ${GITHUB_DEPLOY_KEY_URL}"
	echo "     Click \"Add deploy key\", title e.g. server-$(hostname -s 2>/dev/null || echo host)"
	echo "     Paste the key. Read-only access is enough (leave \"Allow write access\" off)."
	echo ""
	echo "     (Alternative: add the key under your account SSH Keys to access all repos;"
	echo "      a per-repo deploy key is recommended for a single server.)"
	echo "═══════════════════════════════════════════════════════════════════"
	echo ""
}

verify_repo_access() {
	export GIT_SSH_COMMAND="ssh -i ${KEY_FILE} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
	# If HEAD resolves, the deploy key is authorized for this repo.
	git ls-remote "$PRIVATE_REPO_SSH" HEAD >/dev/null 2>&1
}

wait_and_verify_loop() {
	while true; do
		# When piping curl to bash, stdin is the script; use tty for prompts.
		read -r -p "I added the key on GitHub; press Enter to test (q to quit): " ans < /dev/tty || true
		if [ "${ans:-}" = "q" ] || [ "${ans:-}" = "Q" ]; then
			die "Aborted by user."
		fi
		if verify_repo_access; then
			echo "OK: SSH access to the private repository verified."
			return 0
		fi
		echo ""
		echo "Not yet (or the key is not authorized). Checklist:"
		echo "  · Was the full public key pasted as a single line?"
		echo "  · Correct repository → Settings → Deploy keys?"
		echo "  · Wait a few seconds and try again; GitHub may need a moment."
		echo ""
	done
}

resolve_clone_dir() {
	if [ -n "${CLONE_DIR:-}" ]; then
		echo "$CLONE_DIR"
		return
	fi
	if [ "$(id -u)" -eq 0 ]; then
		echo "/opt/cronwork-server-setup"
	else
		echo "${HOME}/cronwork-server-setup"
	fi
}

clone_or_update() {
	local dest="$1"
	# try_repo_access_already_ok veya wait_and_verify sonrası GIT_SSH_COMMAND ayarlı olabilir
	if [ -z "${GIT_SSH_COMMAND:-}" ] && [ -f "$KEY_FILE" ]; then
		export GIT_SSH_COMMAND="ssh -i ${KEY_FILE} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
	fi

	if [ -d "${dest}/.git" ]; then
		echo "Updating existing clone: $dest"
		git -C "$dest" pull --ff-only
	elif [ -d "$dest" ]; then
		die "$dest exists but is not a git repository; move/remove it and run again."
	else
		echo "Cloning: $PRIVATE_REPO_SSH → $dest"
		git clone "$PRIVATE_REPO_SSH" "$dest"
	fi
}

run_installer() {
	local dest="$1"
	local installer="${dest}/install.sh"
	[ -f "$installer" ] || die "install.sh not found: $installer"

	if [ "$(id -u)" -eq 0 ]; then
		echo "Starting installer (root): bash $installer"
		exec bash "$installer"
	else
		echo "The installer must run as root."
		echo "Run:"
		echo "  sudo bash $installer"
		exec sudo bash "$installer"
	fi
}

main() {
	require_root
	echo "cronwork_ — SSH deploy setup and private repository clone"
	echo ""

	ensure_packages_debian
	ensure_ssh_dir

	if ! try_repo_access_already_ok; then
		generate_key_if_needed
		print_instructions
		wait_and_verify_loop
		export GIT_SSH_COMMAND="ssh -i ${KEY_FILE} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
	fi

	local dest
	dest="$(resolve_clone_dir)"
	clone_or_update "$dest"
	run_installer "$dest"
}

main "$@"
