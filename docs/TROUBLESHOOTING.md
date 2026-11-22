# Troubleshooting

## `CANNOT LINK EXECUTABLE` or `bad ELF interpreter`

The binary is not patched to the Termux glibc loader.

```bash
opencode-repatch
```

If the loader is missing:

```bash
pkg install glibc-runner
```

Verify:

```bash
patchelf --print-interpreter "$HOME/.opencode/bin/opencode"
```

Expected:

```text
/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1
```

## `opencode: command not found` after install

Open a new Termux session or refresh the shell cache:

```bash
hash -r
```

Check that the launcher exists:

```bash
ls -l "$PREFIX/bin/opencode"
```

## `opencode upgrade` broke the install

OpenCode replaces the binary and may replace the PTY helper.

```bash
opencode          # once, then quit
opencode-repatch
```

Then restart the service from a new session:

```bash
opencode service restart
```

## PTY checksum mismatch / terminal does not open

OpenCode validates the cached PTY helper by hash. After `patchelf`, the hash
changes, so this project uses a stable copy at:

```text
~/.opencode/bin/opencode-pty
```

The launcher only exports `OPENCODE_PTY_BIN` when the binary stamp matches. If
the helper is stale:

```bash
opencode
# quit
opencode-repatch
```

## Socket error involving `/tmp`

Android does not allow Termux to use `/tmp` reliably. The launcher sets:

```text
OPENCODE_PTY_SOCKET_DIR=$PREFIX/tmp/oc-pty
```

Confirm it exists:

```bash
ls -ld "$PREFIX/tmp/oc-pty"
```

If not, `opencode-repatch` recreates it.

## Service does not start

From a fresh Termux session:

```bash
opencode service status
opencode service restart
opencode-health
```

Check logs:

```bash
ls -lt "$HOME/.local/share/opencode/log" | head
tail -n 100 "$HOME/.local/share/opencode/log/opencode.log"
```

Remove tokens, account IDs, paths, and private data before sharing logs.

## TUI is blank or exits immediately

Try a private server to isolate the shared service:

```bash
opencode --standalone
```

If that works, restart the shared service:

```bash
opencode service restart
```

## Android kills the process

Android 12+ may kill background processes. Try:

- disable battery optimization for Termux,
- keep the Termux notification visible,
- run `termux-wake-lock`,
- avoid switching away for long periods during the first run.

## Installation fails on a non-aarch64 device

This project only supports Android arm64. Check:

```bash
uname -m
```

`aarch64` is supported. `armv7l`, `x86_64`, and `i686` are not.

## Cloned Termux, work profile, or secondary user

This project does **not** support cloned/repackaged Termux apps, app cloners,
work profiles, or secondary Android users.

Termux packages are built for:

```text
/data/data/com.termux/files
```

A secondary user uses a different data path, and a renamed package needs a
rebuilt Termux bootstrap and rebuilt packages. Installing OpenCode inside that
environment requires rebuilding Termux itself, not just cloning the APK.

For a safe test, use a spare device or an emulator with the official Termux
package. Do not use an app cloner for a production setup.

## Running scripts from shared storage

Scripts can live in `/sdcard`, but Termux may not preserve executable bits
there. Run them with `bash` explicitly:

```bash
bash install.sh
bash scripts/health.sh
```

Do not put secrets, session databases, or backups in `/sdcard`.

## Still stuck

Open an issue with:

- Android version and device architecture,
- Termux version and installation source,
- OpenCode version,
- exact command and full error,
- sanitized log excerpt.

Use the issue template if available. Never paste real credentials.
