# cronwork-bootstrap-public

One-shot bootstrap for a server: generates an SSH deploy key, tells you where to paste the public key on GitHub, verifies access, then clones the private [cronwork-server-setup](https://github.com/doguab/cronwork-server-setup) repository and runs `install.sh`.

## Usage (Ubuntu / Debian)

Install `curl` if needed:

```bash
sudo apt-get update && sudo apt-get install -y curl
```

Then run as root or a user with `sudo`:

```bash
curl -fsSL https://raw.githubusercontent.com/doguab/cronwork-bootstrap-public/main/bootstrap.sh | bash
```

What the script does:

1. Creates `~/.ssh/cronwork_github_ed25519` if it does not exist.
2. Prints the public key and a link to add a **Deploy key** on the private repo.
3. After you press Enter, tests access with `git ls-remote`.
4. On success, clones into `/opt/cronwork-server-setup` (as root) or `~/cronwork-server-setup` (non-root) and runs `install.sh`.

## Environment variables

| Variable | Description |
|----------|-------------|
| `PRIVATE_REPO_SSH` | Default: `git@github.com:doguab/cronwork-server-setup.git` |
| `CLONE_DIR` | Clone destination (default for root: `/opt/cronwork-server-setup`) |
| `GITHUB_DEPLOY_KEY_URL` | Link shown in the instructions (Settings → Deploy keys) |

## Security

- Add the deploy key only to the intended private repository; read-only is usually enough.
- This repository is **public** — do not store secrets here.
