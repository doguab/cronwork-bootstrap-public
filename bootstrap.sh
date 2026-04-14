#!/usr/bin/env bash
#
# Public betik: sunucuda SSH deploy anahtarı hazırlar, GitHub doğrulaması yapar,
# ardından private cronwork-server-setup reposunu klonlar ve install.sh çalıştırır.
#
# Örnek:
#   curl -fsSL https://raw.githubusercontent.com/doguab/cronwork-bootstrap-public/main/bootstrap.sh | bash
# veya:
#   wget -qO- ... | bash
#
# Ortam değişkenleri (isteğe bağlı):
#   PRIVATE_REPO_SSH  — varsayılan: git@github.com:doguab/cronwork-server-setup.git
#   CLONE_DIR         — varsayılan: root ise /opt/cronwork-server-setup, değilse ~/cronwork-server-setup
#
set -euo pipefail

PRIVATE_REPO_SSH="${PRIVATE_REPO_SSH:-git@github.com:doguab/cronwork-server-setup.git}"
KEY_NAME="cronwork_github_ed25519"
KEY_FILE="${HOME}/.ssh/${KEY_NAME}"

GITHUB_DEPLOY_KEY_URL="${GITHUB_DEPLOY_KEY_URL:-https://github.com/doguab/cronwork-server-setup/settings/keys}"

die() {
	echo "Hata: $*" >&2
	exit 1
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

generate_key_if_needed() {
	if [ -f "$KEY_FILE" ]; then
		echo "Mevcut anahtar kullanılıyor: $KEY_FILE"
		return 0
	fi
	echo "Yeni SSH anahtarı oluşturuluyor: $KEY_FILE"
	ssh-keygen -t ed25519 -a 100 -f "$KEY_FILE" -N "" -C "cronwork-deploy-$(hostname -s 2>/dev/null || echo server)-$(date +%Y%m%d)"
	chmod 600 "$KEY_FILE" "${KEY_FILE}.pub"
}

print_instructions() {
	local pubkey
	pubkey="$(cat "${KEY_FILE}.pub")"
	echo ""
	echo "═══════════════════════════════════════════════════════════════════"
	echo "  1) Aşağıdaki PUBLIC anahtarın tamamını kopyalayın (tek satır):"
	echo "═══════════════════════════════════════════════════════════════════"
	echo ""
	echo "$pubkey"
	echo ""
	echo "═══════════════════════════════════════════════════════════════════"
	echo "  2) GitHub’da bu private repoya deploy key ekleyin:"
	echo "      ${GITHUB_DEPLOY_KEY_URL}"
	echo "     “Add deploy key” → başlık: örn. sunucu-$(hostname -s 2>/dev/null || echo host)"
	echo "     İçeriği yapıştırın. Salt okunur (Allow write access kapalı) yeterli."
	echo ""
	echo "     (Alternatif: anahtarı kendi hesabınızın SSH Keys sayfasına eklerseniz"
	echo "      tüm repolara erişir; deploy key yalnızca bu repo için önerilir.)"
	echo "═══════════════════════════════════════════════════════════════════"
	echo ""
}

verify_repo_access() {
	export GIT_SSH_COMMAND="ssh -i ${KEY_FILE} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
	# HEAD okunabiliyorsa deploy key doğru demektir.
	git ls-remote "$PRIVATE_REPO_SSH" HEAD >/dev/null 2>&1
}

wait_and_verify_loop() {
	while true; do
		# curl | bash kullanıldığında stdin betik akışıdır; etkileşim için tty şart.
		read -r -p "Anahtarı GitHub’a ekledim; bağlantıyı test etmek için Enter’a basın (çıkmak için q): " ans < /dev/tty || true
		if [ "${ans:-}" = "q" ] || [ "${ans:-}" = "Q" ]; then
			die "Kullanıcı iptal etti."
		fi
		if verify_repo_access; then
			echo "Tamam: Private repoya SSH ile erişim doğrulandı."
			return 0
		fi
		echo ""
		echo "Henüz olmadı (veya anahtar henüz yetkili değil). Kontrol listesi:"
		echo "  · Public key tam ve tek satır mı yapıştırıldı?"
		echo "  · Doğru repository’nin Deploy keys bölümü mü? (user/repo)"
		echo "  · Birkaç saniye sonra GitHub tarafı güncellenmiş olabilir; tekrar deneyin."
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
	export GIT_SSH_COMMAND="ssh -i ${KEY_FILE} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

	if [ -d "${dest}/.git" ]; then
		echo "Mevcut klon güncelleniyor: $dest"
		git -C "$dest" pull --ff-only
	elif [ -d "$dest" ]; then
		die "$dest var ama git deposu değil; elle taşıyın/silin ve tekrar çalıştırın."
	else
		echo "Klonlanıyor: $PRIVATE_REPO_SSH → $dest"
		git clone "$PRIVATE_REPO_SSH" "$dest"
	fi
}

run_installer() {
	local dest="$1"
	local installer="${dest}/install.sh"
	[ -f "$installer" ] || die "install.sh bulunamadı: $installer"

	if [ "$(id -u)" -eq 0 ]; then
		echo "Kurulum başlıyor (root): bash $installer"
		exec bash "$installer"
	else
		echo "Kurulum root ile çalıştırılmalı."
		echo "Şunu çalıştırın:"
		echo "  sudo bash $installer"
		exec sudo bash "$installer"
	fi
}

main() {
	echo "cronwork_ — SSH deploy hazırlığı ve private repo çekimi"
	echo ""

	ensure_packages_debian
	ensure_ssh_dir
	generate_key_if_needed
	print_instructions
	wait_and_verify_loop

	local dest
	dest="$(resolve_clone_dir)"
	clone_or_update "$dest"
	run_installer "$dest"
}

main "$@"
