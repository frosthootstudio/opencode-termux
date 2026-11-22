# OpenCode Native for Termux

Install **OpenCode 2** on **Termux (Android aarch64)** without proot, without
Ubuntu, and without root.

> **Unofficial community project.** Not affiliated with OpenCode, Termux, or
> their maintainers. Use at your own risk.

---

## Why this exists

Most Termux guides run OpenCode inside a proot Ubuntu container. This project
runs the official `linux-arm64` binary directly on Termux by:

1. installing the Termux `glibc-runner` loader,
2. patching the ELF interpreter with `patchelf`,
3. using a small launcher that keeps the PTY helper and socket directory in
   Termux-friendly locations.

The result is lighter than proot and stays inside the Android app sandbox.

---

## Requirements

- Android **aarch64 / arm64** device.
- Termux installed from **F-Droid** or the official GitHub releases.
  The Play Store version is outdated.
- About **500 MB** free space for the OpenCode binary and cache.
- Internet connection during installation and first run.
- No root required.

Android 12+ may kill long-running background processes. For long sessions:

- disable battery optimization for Termux,
- run `termux-wake-lock`,
- keep the Termux notification visible.

## Compatibility

Supported:

- Official Termux package `com.termux`.
- Primary Android user / owner profile.
- Android aarch64.

Not supported:

- Cloned or repackaged Termux apps.
- App cloners, dual-app containers, or virtual spaces.
- Work profiles or secondary Android users.
- Custom Termux package names or prefixes.

Termux packages are compiled for `/data/data/com.termux/files`. A secondary
user gets a different data path, and a renamed package needs a rebuilt
bootstrap and rebuilt packages. This is a Termux limitation, not something the
OpenCode installer can fix by itself.

---

## Quick start

```bash
git clone https://github.com/frosthootstudio/opencode-termux.git
cd opencode-termux
bash install.sh
```

Then:

```bash
opencode          # first run: let it download the PTY helper, then quit
opencode-repatch  # patch the helper and write the stable launcher
opencode -c       # open the TUI again
opencode-health   # optional sanity check
```

If `opencode` is not found, open a new Termux session or run `hash -r`.

---

## Sandbox test

Try the installer without touching your normal OpenCode installation:

```bash
bash install.sh --sandbox
```

Default sandbox:

```text
~/.opencode-sandbox/
├── bin/
│   ├── opencode
│   ├── opencode-repatch
│   ├── opencode-health
│   └── opencode-backup
├── home/          # isolated HOME, config, sessions, cache
├── lib/
└── tmp/
```

Run it:

```bash
~/.opencode-sandbox/bin/opencode
~/.opencode-sandbox/bin/opencode-repatch
~/.opencode-sandbox/bin/opencode-health
```

The sandbox starts with its own empty config and no provider credentials. Log
in inside the sandbox if needed:

```bash
~/.opencode-sandbox/bin/opencode auth login
```

or use `/connect` in the TUI.

The sandbox uses the real Termux glibc loader and prefix, but its HOME,
config, session data, cache, socket, and backups are isolated. It runs with a
private server (`--standalone`) instead of the shared background service.

Delete everything with:

```bash
rm -rf ~/.opencode-sandbox
```

No files are written to `~/.opencode/bin` or `$PREFIX/bin` in sandbox mode.

---

## What the installer does

- Installs `glibc-repo`, `glibc-runner`, `patchelf`, `curl`, `tar`, and `sqlite`.
- Downloads the latest official `@opencode/cli-linux-arm64` package from npm.
- Backs up an existing binary before replacing it.
- Patches the binary to use Termux's glibc loader.
- Writes the `opencode` launcher to `$PREFIX/bin/opencode`.
- Installs optional helpers:
  - `opencode-repatch` — re-patch after an OpenCode upgrade.
  - `opencode-health` — read-only health check.
  - `opencode-backup` — backup config/state (optional, see below).

It does **not** install personal configuration, bots, or third-party
integrations.

### Dry run and checks

```bash
bash install.sh --check     # inspect prerequisites without changing anything
bash install.sh --dry-run   # print planned actions without installing
```

Pin a version if needed:

```bash
OPENCODE_VERSION=2.3.2 bash install.sh
```

---

## After an OpenCode upgrade

`opencode upgrade` replaces the binary, so the glibc interpreter and PTY helper
must be patched again.

```bash
opencode upgrade
opencode          # run once so the new PTY helper is downloaded, then quit
opencode-repatch
```

Then restart the background service from a **new Termux session** (not from the
TUI that is currently open):

```bash
opencode service restart
opencode-health
```

---

## Helper commands

| Command | Purpose |
|---|---|
| `opencode` | Launcher for the patched binary |
| `opencode-repatch` | Re-patch binary + PTY helper after upgrade |
| `opencode-health` | Read-only checks for loader, binary, PTY, service, storage |
| `opencode-backup` | Create a private backup of config/state |

### Backup

By default the backup contains config and state only. Session database and
credentials are excluded unless you opt in:

```bash
opencode-backup                # config + state
opencode-backup --with-db      # also session DB (contains credentials!)
opencode-backup --encrypt      # GPG symmetric encryption
opencode-backup --output DIR   # custom output directory
```

For non-interactive encryption, set `OPENCODE_BACKUP_PASSPHRASE_FILE` to a
mode-600 file containing the passphrase.

Backups are written with mode `600` to `~/.opencode/backups` by default.
Treat them as secrets.

---

## Tested environment

- Android 16, aarch64
- Termux 0.118.3
- OpenCode 2.3.2

Other Android versions and devices may work, but the glibc/PTY behavior can
vary. Please include your Android version, Termux version, and OpenCode version
when reporting an issue.

---

## Project layout

```text
.
├── install.sh
├── scripts/
│   ├── repatch.sh
│   ├── health.sh
│   └── backup.sh
├── docs/
│   ├── INSTALL.md
│   ├── TROUBLESHOOTING.md
│   └── TECHNICAL.md
├── SECURITY.md
├── CONTRIBUTING.md
├── CHANGELOG.md
└── LICENSE
```

---

## Security notes

- Everything runs as your Termux app user. **Do not run as root.**
- OpenCode configuration, sessions, and backups can contain credentials.
  Keep them private and never commit them.
- This installer downloads an official binary from npm. Review the script before
  running it.
- Do not install untrusted `AGENTS.md`, skills, plugins, or MCP servers.
- Report security issues according to [SECURITY.md](SECURITY.md).

---

## Disclaimer

This is an unofficial workaround. OpenCode upgrades can break the glibc or PTY
patch. There is no warranty. Test in a recoverable environment first.

---

## License

MIT. See [LICENSE](LICENSE).
