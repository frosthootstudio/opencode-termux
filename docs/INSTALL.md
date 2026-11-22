# Installation

## 1. Prepare Termux

Install Termux from **F-Droid** or the official GitHub releases. Do not use the
outdated Play Store build.

Open Termux and update packages:

```bash
pkg update -y
pkg upgrade -y
```

For long sessions, disable Android battery optimization for Termux and keep
`termux-wake-lock` running.

## 2. Clone and run

```bash
git clone https://github.com/frosthootstudio/opencode-termux.git
cd opencode-termux
bash install.sh
```

The installer will:

- install `glibc-repo`, `glibc-runner`, `patchelf`, `curl`, `tar`, `sqlite`,
  and `gnupg`,
- download the official `@opencode/cli-linux-arm64` package from npm,
- patch the ELF interpreter,
- install the launcher and helper commands.

### Check first

```bash
bash install.sh --check
bash install.sh --dry-run
```

### Pin a version

```bash
OPENCODE_VERSION=2.3.2 bash install.sh
```

## 3. First run

```bash
opencode
```

Let OpenCode start and download its PTY helper, then quit.

```bash
opencode-repatch
opencode -c
```

`opencode-repatch` copies and patches the helper, then writes the stable
launcher. It does not restart the service.

Check the installation:

```bash
opencode-health
```

## 4. Upgrade

```bash
opencode upgrade
opencode          # once, then quit
opencode-repatch
```

Restart the background service from a **new Termux session**:

```bash
opencode service restart
opencode-health
```

Do not restart the service from inside the TUI that is currently open.

## 5. Uninstall

Remove the launcher, binary, and helpers:

```bash
rm -f "$PREFIX/bin/opencode" \
      "$PREFIX/bin/opencode-repatch" \
      "$PREFIX/bin/opencode-health" \
      "$PREFIX/bin/opencode-backup"
rm -rf "$HOME/.opencode/bin"
```

Configuration and sessions are separate. Remove them only if you want a full
reset:

```bash
rm -rf "$HOME/.config/opencode" \
       "$HOME/.local/share/opencode" \
       "$HOME/.local/state/opencode"
```

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `PREFIX` | `/data/data/com.termux/files/usr` | Termux prefix |
| `HOME` | `/data/data/com.termux/files/home` | Termux home |
| `TMPDIR` | `$PREFIX/tmp` | Temporary files |
| `OPENCODE_VERSION` | latest npm | Pin installer version |
| `OPENCODE_BIN` | `$HOME/.opencode/bin/opencode` | Override binary path for repatch |
| `OPENCODE_BACKUP_DIR` | `$HOME/.opencode/backups` | Backup output |
| `OPENCODE_BACKUP_PASSPHRASE_FILE` | unset | Non-interactive GPG passphrase |

## Tested environment

- Android 16, aarch64
- Termux 0.118.3
- OpenCode 2.3.2

Other devices may work. Include your versions when reporting an issue.
