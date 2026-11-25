# Changelog

## 0.2.3 — 2026-11-25

- Clarify the difference between the official OpenCode Mobile companion app
  (remote for a computer) and this native Termux runtime.

## 0.2.2 — 2026-11-25

- Document tested OpenCode 2.4.1 fresh sandbox install and upgrade path.
- Record PTY helper 0.6.0 in the tested matrix.

## 0.2.1 — 2026-11-24

- Install `which` automatically; fixes `opencode upgrade` failing with
  `which: command not found`.
- Health check warns when `which` is missing.
- Document the upgrade error and fix.

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
