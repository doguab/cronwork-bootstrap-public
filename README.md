# cronwork-bootstrap-public

Sunucuda tek komutla SSH deploy anahtarı oluşturur, GitHub’a public key’i nereye yapıştıracağınızı söyler, erişimi doğrular ve [cronwork-server-setup](https://github.com/doguab/cronwork-server-setup) private reposunu klonlayıp kurulumu başlatır.

## Kullanım (Ubuntu / Debian)

Önce `curl` yoksa:

```bash
sudo apt-get update && sudo apt-get install -y curl
```

Ardından (root veya sudo yetkili kullanıcı):

```bash
curl -fsSL https://raw.githubusercontent.com/doguab/cronwork-bootstrap-public/main/bootstrap.sh | bash
```

Betik:

1. `~/.ssh/cronwork_github_ed25519` anahtarını oluşturur (yoksa).
2. Public key’i ekrana basar ve private repoya **Deploy key** ekleme bağlantısını verir.
3. Siz anahtarı GitHub’da ekledikten sonra Enter ile test eder (`git ls-remote`).
4. Başarılıysa repoyu `/opt/cronwork-server-setup` (root) veya `~/cronwork-server-setup` altına klonlar ve `install.sh` çalıştırır.

## Ortam değişkenleri

| Değişken | Açıklama |
|----------|----------|
| `PRIVATE_REPO_SSH` | Varsayılan: `git@github.com:doguab/cronwork-server-setup.git` |
| `CLONE_DIR` | Klon hedefi (belirtmezseniz root: `/opt/cronwork-server-setup`) |
| `GITHUB_DEPLOY_KEY_URL` | Talimat metninde gösterilen Settings → Keys linki |

## Güvenlik

- Deploy key’i yalnızca ilgili private repoya ekleyin; yazma izni genelde gerekmez.
- Bu repo **public**tir; içinde gizli bilgi tutmayın.
