# Technical notes

## Why a custom installer is needed

OpenCode ships an official `linux-arm64` binary built against glibc. Termux uses
Bionic libc and a different dynamic loader. Running the binary directly fails
with errors such as:

```text
CANNOT LINK EXECUTABLE "opencode": library "libc.so.6" not found
```

The usual workaround is a proot Ubuntu container. This project avoids proot by
using Termux's glibc compatibility layer.

## Components

### 1. glibc loader

`glibc-runner` provides:

```text
$PREFIX/glibc/lib/ld-linux-aarch64.so.1
```

The installer patches the OpenCode ELF interpreter to point at this loader:

```bash
patchelf --set-interpreter "$LOADER" "$HOME/.opencode/bin/opencode"
```

### 2. Launcher

The launcher is installed at `$PREFIX/bin/opencode`:

```bash
unset LD_PRELOAD
export OPENCODE_PTY_SOCKET_DIR="$PREFIX/tmp/oc-pty"
exec "$HOME/.opencode/bin/opencode" "$@"
```

It also exports `OPENCODE_PTY_BIN` when a patched PTY helper is available and
its stamp matches the current binary.

### 3. PTY helper

OpenCode downloads a helper binary at runtime and validates its hash. Patching
the helper with `patchelf` changes that hash, so the cached helper is rejected.

The project copies the newest cached helper to a stable path:

```text
~/.opencode/bin/opencode-pty
```

`opencode-repatch` patches that copy and writes a stamp containing the main
binary's mtime and size. The launcher only uses the stable helper when the stamp
matches. After an upgrade, the stamp is intentionally invalidated so OpenCode
downloads a fresh helper.

### 4. Socket directory

Android does not allow the Termux app to write to `/tmp`. The launcher sets:

```text
OPENCODE_PTY_SOCKET_DIR=$PREFIX/tmp/oc-pty
```

This directory lives inside the Termux app sandbox and is writable by the app
user.

## Install flow

```text
pkg install glibc-repo
pkg install glibc-runner patchelf curl tar sqlite gnupg
curl npm @opencode/cli-linux-arm64
tar -xzf
install binary -> ~/.opencode/bin/opencode
patchelf --set-interpreter ...
write launcher -> $PREFIX/bin/opencode
install helpers -> $PREFIX/bin/opencode-{repatch,health,backup}
```

## Upgrade flow

```text
opencode upgrade
opencode          # downloads fresh PTY helper, then quit
opencode-repatch  # patch binary + helper, write stamp + launcher
opencode service restart
```

## Design boundaries

- No root.
- No proot or Ubuntu image.
- No modification of Android system partitions.
- No bots or third-party integrations.
- No bundled OpenCode binary in this repository; the installer downloads from
  the official npm package.

## Failure modes

- OpenCode changes its PTY helper layout or validation.
- glibc-runner changes its loader path.
- npm package layout changes.
- Android kills the service or restricts background execution.

These are the main reasons the project needs maintenance after upstream
releases. Pin a known-good OpenCode version with `OPENCODE_VERSION` if needed.
