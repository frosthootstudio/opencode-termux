# Security Policy

## Reporting a vulnerability

Please **do not open a public issue** for security problems.

Use GitHub's private vulnerability reporting:

1. Open the repository on GitHub.
2. Go to **Security**.
3. Choose **Report a vulnerability**.

Include:

- affected file or command,
- steps to reproduce,
- expected and actual result,
- Android, Termux, and OpenCode versions,
- sanitized logs (remove tokens, account IDs, paths, and private keys).

Never include real API keys, bot tokens, passwords, session databases, or
private keys in a report, screenshot, or log.

---

## Secrets and local data

This project does not require credentials to install OpenCode. However, normal
OpenCode usage may create files such as:

```text
~/.config/opencode/
~/.local/share/opencode/
~/.local/state/opencode/
~/.opencode/backups/
```

Those directories can contain session history, provider credentials, and
personal configuration. They are **not** part of this repository.

`opencode-backup` excludes common secret files by default and only includes the
session database with `--with-db`. Even so, treat every backup as sensitive.

Recommended permissions:

```bash
chmod 700 ~/.config/opencode ~/.local/share/opencode ~/.local/state/opencode
chmod 600 ~/.config/opencode/*.json 2>/dev/null || true
```

Do not store secrets in `/sdcard`. Shared storage can be read by other Android
apps and does not reliably support Unix permissions.

---

## Running third-party content

OpenCode can load `AGENTS.md`, skills, plugins, MCP servers, and commands.
These may execute code or send data to external services.

- Review third-party content before use.
- Prefer official or pinned sources.
- Do not run a Telegram bot or shell agent with broad access unless you
  understand the risk.
- Keep API keys scoped and revocable.

---

## Supported versions

Security fixes target the latest commit on `main`. Older commits and modified
forks are not supported.
