# cronwork-bootstrap-public

One-shot bootstrap for a server: generates an SSH deploy key, tells you where to paste the public key on GitHub, verifies access, then clones the private [cronwork-server-setup](https://github.com/doguab/cronwork-server-setup) repository and runs `install.sh`.

## Onboarding (shortest path)

1. Use a **clean Ubuntu 22.04 or 24.04 LTS** VPS; log in over **SSH** (normal terminal).
2. Run the **bootstrap** command below (needs `sudo`).
3. **Copy the printed public key** → GitHub → private repo **Settings → Deploy keys → Add deploy key** (read-only is fine).
4. Press **Enter** in the terminal until access checks pass.
5. When the **menu** appears, choose **1** (server setup), answer the questions, and **wait** until it finishes (Hestia can take 10–20+ minutes).
6. **Reboot** if the installer asks you to.
7. Open the panel URL from the final summary (port **8083**). Login user is shown there (often `hestiaadmin`); password is in `/root/.cronwork-server-setup/hestia-admin-password` on the server.
8. Optional later: run **`sudo bash /opt/cronwork-server-setup/install.sh`** again and use **2** for stricter SSH (have your IP ready).

## Usage (Ubuntu / Debian)

Install `curl` if needed:

```bash
sudo apt-get update && sudo apt-get install -y curl
```

**Must run as root** (the script installs packages and clones to `/opt`):

```bash
curl -fsSL https://raw.githubusercontent.com/doguab/cronwork-bootstrap-public/main/bootstrap.sh | sudo bash
```

What the script does:

1. Creates `/root/.ssh/cronwork_github_ed25519` if it does not exist.
2. Prints the public key and a link to add a **Deploy key** on the private repo.
3. After you press Enter, tests access with `git ls-remote`.
4. On success, clones into `/opt/cronwork-server-setup` and runs `install.sh`.

## Environment variables

| Variable | Description |
|----------|-------------|
| `PRIVATE_REPO_SSH` | Default: `git@github.com:doguab/cronwork-server-setup.git` |
| `CLONE_DIR` | Clone destination (default for root: `/opt/cronwork-server-setup`) |
| `GITHUB_DEPLOY_KEY_URL` | Link shown in the instructions (Settings → Deploy keys) |

## Security

- Add the deploy key only to the intended private repository; read-only is usually enough.
- This repository is **public** — do not store secrets here.
