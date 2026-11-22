# Changelog

## 0.2.0 — 2026-11-22

- Add `--sandbox` install mode with isolated HOME, config, sessions, cache,
  socket, and backups.
- Sandbox runs with a private server (`--standalone`).
- Sandbox helper wrappers for repatch, health, and backup.
- Add download retries and a clearer curl failure path.
- Document clone/work-profile limitations.

## 0.1.0 — 2026-11-22

Initial public release.

- Install OpenCode 2 native on Termux aarch64 without proot or root.
- Patch the ELF interpreter to use the Termux glibc loader.
- Stable launcher with PTY helper and Termux-friendly socket directory.
- `opencode-repatch` for upgrades.
- `opencode-health` read-only checks.
- `opencode-backup` with optional session database and GPG encryption.
- Documentation for installation, troubleshooting, and internals.
