# Contributing

Thanks for testing and improving this project.

## Before you start

This project targets **Termux on Android aarch64**. Changes should stay inside
that scope unless the issue explicitly asks for something else.

Please do not include any of the following in a pull request:

- API keys, bot tokens, passwords, or private keys,
- `~/.config/opencode/` contents,
- session databases or backups,
- personal device IDs, usernames, phone numbers, or screenshots with personal
  data,
- large binaries or vendor bundles.

## Development checks

Run these before opening a pull request:

```bash
bash -n install.sh
bash -n scripts/repatch.sh
bash -n scripts/health.sh
bash -n scripts/backup.sh
```

If `shellcheck` is available:

```bash
shellcheck install.sh scripts/*.sh
```

Also test:

```bash
bash install.sh --check
bash install.sh --dry-run
```

## Testing on a device

At minimum, report:

- Android version,
- device architecture,
- Termux version and installation source,
- OpenCode version,
- whether the issue happens on a fresh install or after `opencode upgrade`.

A useful test sequence:

1. Fresh Termux with no `~/.opencode`.
2. `bash install.sh`.
3. `opencode` → quit.
4. `opencode-repatch`.
5. `opencode -c`.
6. `opencode-health`.
7. Reboot and confirm `opencode` still starts.

## Style

- Bash with `set -euo pipefail`.
- Quote variables.
- Prefer small functions and clear error messages.
- Do not add dependencies unless they are available in Termux.
- Keep scripts readable; avoid clever one-liners for destructive operations.

## Pull requests

Describe:

- what changed,
- why it is needed,
- how it was tested,
- any known limitations.

By submitting a contribution, you agree that it is licensed under the MIT
License of this repository.
