#!/data/data/com.termux/files/usr/bin/bash
# Unofficial OpenCode native installer for Termux aarch64.
# No proot, no root, no Ubuntu.
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
TMPDIR="${TMPDIR:-$PREFIX/tmp}"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${OPENCODE_VERSION:-}"
DRY_RUN=0
CHECK_ONLY=0
SANDBOX=""

usage() {
  cat <<'EOF'
Usage: bash install.sh [options]

Options:
  --sandbox [DIR]  Install into an isolated sandbox (default:
                   ~/.opencode-sandbox). Does not touch the normal install.
  --check          Check prerequisites and exit.
  --dry-run        Print planned actions without changing anything.
  --version VER    Install a specific OpenCode version (default: latest).
  -h, --help       Show this help.

Environment:
  OPENCODE_VERSION      Same as --version.
  OPENCODE_SANDBOX_DIR  Default sandbox directory.
  PREFIX                Termux prefix (auto-detected).
  HOME                  Termux home (auto-detected).
EOF
}

say() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --sandbox)
      if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
        SANDBOX="$2"
        shift 2
      else
        SANDBOX="${OPENCODE_SANDBOX_DIR:-$HOME/.opencode-sandbox}"
        shift
      fi
      ;;
    --check) CHECK_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --version)
      [ $# -ge 2 ] || die "--version butuh nilai"
      VERSION="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opsi tidak dikenal: $1" ;;
  esac
done

[ "$(uname -m)" = "aarch64" ] || die "Skrip ini hanya untuk aarch64/arm64."
command -v pkg >/dev/null 2>&1 || die "Ini bukan Termux: perintah 'pkg' tidak ada."

if [ -n "$SANDBOX" ]; then
  SANDBOX="${SANDBOX%/}"
  case "$SANDBOX" in
    "$HOME"/*) ;;
    *) die "Sandbox harus berada di dalam \$HOME: $SANDBOX" ;;
  esac
  SANDBOX_HOME="$SANDBOX/home"
  BIN_DIR="$SANDBOX_HOME/.opencode/bin"
  BIN="$BIN_DIR/opencode"
  LAUNCHER="$SANDBOX/bin/opencode"
  SANDBOX_BIN="$SANDBOX/bin"
  SANDBOX_LIB="$SANDBOX/lib"
  SANDBOX_TMP="$SANDBOX/tmp"
else
  BIN_DIR="$HOME/.opencode/bin"
  BIN="$BIN_DIR/opencode"
  LAUNCHER="$PREFIX/bin/opencode"
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  say "Pemeriksaan lingkungan"
  info "arch:        $(uname -m)"
  info "prefix:      $PREFIX"
  info "home:        $HOME"
  info "tmpdir:      $TMPDIR"
  info "mode:        $([ -n "$SANDBOX" ] && echo sandbox || echo normal)"
  [ -n "$SANDBOX" ] && info "sandbox:     $SANDBOX"
  info "binary:      $BIN"
  info "launcher:    $LAUNCHER"
  info "loader:      $([ -f "$LOADER" ] && echo ada || echo 'belum ada (akan dipasang)')"
  for cmd in pkg curl tar patchelf sqlite3; do
    if command -v "$cmd" >/dev/null 2>&1; then
      info "command:     $cmd ok"
    else
      info "command:     $cmd belum ada"
    fi
  done
  info "disk:        $(df -h "$HOME" 2>/dev/null | awk 'NR==2 {print $4 " tersedia"}')"
  exit 0
fi

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '+ %s\n' "$*"
  else
    "$@"
  fi
}

say "Memperbarui paket Termux"
run pkg update -y

say "Menambahkan repo glibc"
run pkg install -y glibc-repo
run pkg update -y

say "Memasang dependensi"
run pkg install -y glibc-runner patchelf curl tar sqlite gnupg

if [ "$DRY_RUN" -eq 0 ]; then
  [ -f "$LOADER" ] || die "Loader glibc tidak ditemukan: $LOADER"
  command -v patchelf >/dev/null 2>&1 || die "patchelf tidak terpasang"
  command -v curl >/dev/null 2>&1 || die "curl tidak terpasang"
  command -v tar >/dev/null 2>&1 || die "tar tidak terpasang"
fi

if [ -z "$VERSION" ]; then
  VERSION="$(curl -fsSL https://registry.npmjs.org/@opencode/cli/latest 2>/dev/null \
    | grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 | sed 's/.*"\([^"]*\)"$/\1/')" || VERSION=""
fi
[ -n "$VERSION" ] || VERSION="2.3.2"
VERSION="${VERSION#v}"
say "Versi OpenCode: $VERSION"

TMP="$TMPDIR/opencode-install"
SRC=""
if [ "$DRY_RUN" -eq 1 ]; then
  info "[dry-run] download @opencode/cli-linux-arm64@$VERSION"
  info "[dry-run] extract ke $TMP"
else
  rm -rf "$TMP"
  mkdir -p "$TMP"
  say "Mengunduh binary linux-arm64 (±240 MB)"
  curl -fL --retry 5 --retry-delay 3 --retry-all-errors --progress-bar \
    -o "$TMP/opencode.tgz" \
    "https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-${VERSION}.tgz"
  say "Mengekstrak"
  tar -xzf "$TMP/opencode.tgz" -C "$TMP"
  SRC="$(find "$TMP" -type f -name opencode | head -1)"
  [ -n "$SRC" ] || die "Binary 'opencode' tidak ditemukan di dalam paket."
fi

if [ -x "$BIN" ] && [ "$DRY_RUN" -eq 0 ]; then
  BAK="$BIN.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$BIN" "$BAK"
  info "Binary lama dibackup: $BAK"
fi

say "Memasang binary"
run mkdir -p "$BIN_DIR"
if [ -n "$SANDBOX" ] && [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$SANDBOX" "$SANDBOX_BIN" "$SANDBOX_LIB" "$SANDBOX_TMP"
  chmod 700 "$SANDBOX" 2>/dev/null || true
fi
if [ "$DRY_RUN" -eq 1 ]; then
  info "[dry-run] install -m 755 opencode $BIN"
  info "[dry-run] patchelf --set-interpreter $LOADER $BIN"
else
  install -m 755 "$SRC" "$BIN"
  patchelf --set-interpreter "$LOADER" "$BIN"
  GOT="$(patchelf --print-interpreter "$BIN")"
  [ "$GOT" = "$LOADER" ] || die "Interpreter tidak valid: '$GOT'"
  info "interpreter: $GOT"
fi

write_normal_launcher() {
  cat > "$LAUNCHER" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$HOME/.opencode/bin/opencode"
PTY="$HOME/.opencode/bin/opencode-pty"
STAMP="$HOME/.opencode/bin/.opencode-pty.stamp"
SOCKET_DIR="$PREFIX/tmp/oc-pty"
mkdir -p "$SOCKET_DIR" 2>/dev/null || true
chmod 700 "$SOCKET_DIR" 2>/dev/null || true
export OPENCODE_PTY_SOCKET_DIR="$SOCKET_DIR"
if [ -x "$PTY" ] && [ -f "$STAMP" ] && [ "$(stat -c '%Y:%s' "$BIN" 2>/dev/null)" = "$(cat "$STAMP" 2>/dev/null)" ]; then
  export OPENCODE_PTY_BIN="$PTY"
fi
exec "$BIN" "$@"
EOF
  chmod 755 "$LAUNCHER"
}

write_sandbox_wrapper() {
  local path="$1" script="$2" restore="$3"
  cat > "$path" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
. "\$(dirname "\$0")/_env.sh"
rc=0
bash "\$SANDBOX/lib/$script" "\$@" || rc=\$?
EOF
  if [ "$restore" -eq 1 ]; then
    cat >> "$path" <<'EOF'
cp "$SANDBOX/lib/launcher.txt" "$SANDBOX/bin/opencode"
chmod 755 "$SANDBOX/bin/opencode"
EOF
  fi
  printf 'exit "$rc"\n' >> "$path"
  chmod 755 "$path"
}

write_sandbox_files() {
  mkdir -p "$SANDBOX_BIN" "$SANDBOX_LIB" "$SANDBOX_TMP"
  cat > "$SANDBOX_BIN/_env.sh" <<'EOF'
SANDBOX="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SANDBOX
export HOME="$SANDBOX/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export TMPDIR="$SANDBOX/tmp"
mkdir -p "$TMPDIR" 2>/dev/null || true
export OPENCODE_PTY_SOCKET_DIR="$SANDBOX/tmp/oc-pty"
export OPENCODE_SOCKET_DIR="$SANDBOX/tmp/oc-pty"
export OPENCODE_BIN="$HOME/.opencode/bin/opencode"
export OPENCODE_PTY="$HOME/.opencode/bin/opencode-pty"
export OPENCODE_LAUNCHER="$SANDBOX/bin/opencode"
export OPENCODE_BACKUP_DIR="$SANDBOX/backups"
export OPENCODE_SANDBOX=1
EOF
  chmod 644 "$SANDBOX_BIN/_env.sh"

  cat > "$SANDBOX_LIB/launcher.txt" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
unset LD_PRELOAD
. "$(dirname "$0")/_env.sh"
BIN="$OPENCODE_BIN"
PTY="$OPENCODE_PTY"
STAMP="$HOME/.opencode/bin/.opencode-pty.stamp"
SOCKET_DIR="$OPENCODE_PTY_SOCKET_DIR"
mkdir -p "$SOCKET_DIR" 2>/dev/null || true
chmod 700 "$SOCKET_DIR" 2>/dev/null || true
if [ -x "$PTY" ] && [ -f "$STAMP" ] && [ "$(stat -c '%Y:%s' "$BIN" 2>/dev/null)" = "$(cat "$STAMP" 2>/dev/null)" ]; then
  export OPENCODE_PTY_BIN="$PTY"
fi
exec "$BIN" --standalone "$@"
EOF
  chmod 644 "$SANDBOX_LIB/launcher.txt"
  cp "$SANDBOX_LIB/launcher.txt" "$SANDBOX_BIN/opencode"
  chmod 755 "$SANDBOX_BIN/opencode"

  for name in repatch health backup; do
    src="$HERE/scripts/$name.sh"
    if [ -f "$src" ]; then
      install -m 755 "$src" "$SANDBOX_LIB/$name.sh"
    else
      info "lewati: $src tidak ada"
    fi
  done
  write_sandbox_wrapper "$SANDBOX_BIN/opencode-repatch" "repatch.sh" 1
  write_sandbox_wrapper "$SANDBOX_BIN/opencode-health" "health.sh" 0
  write_sandbox_wrapper "$SANDBOX_BIN/opencode-backup" "backup.sh" 0
}

say "Menulis launcher"
if [ "$DRY_RUN" -eq 1 ]; then
  info "[dry-run] tulis $LAUNCHER"
else
  if [ -n "$SANDBOX" ]; then
    write_sandbox_files
  else
    write_normal_launcher
  fi
fi

say "Memasang helper"
if [ -n "$SANDBOX" ]; then
  info "sandbox helpers: $SANDBOX_BIN/opencode-{repatch,health,backup}"
else
  for name in repatch health backup; do
    src="$HERE/scripts/$name.sh"
    dest="$PREFIX/bin/opencode-$name"
    if [ -f "$src" ]; then
      run install -m 755 "$src" "$dest"
    else
      info "lewati: $src tidak ada"
    fi
  done
fi

if [ "$DRY_RUN" -eq 0 ]; then
  rm -rf "$TMP"
  hash -r
  say "Verifikasi"
  "$LAUNCHER" --version
else
  info "[dry-run] selesai; tidak ada perubahan."
  exit 0
fi

say "Selesai"
if [ -n "$SANDBOX" ]; then
  cat <<EOF
Sandbox: $SANDBOX

Langkah berikutnya:
  1. Jalankan: $SANDBOX/bin/opencode
     Lalu keluar.
  2. Jalankan: $SANDBOX/bin/opencode-repatch
  3. Buka lagi: $SANDBOX/bin/opencode -c
  4. Cek: $SANDBOX/bin/opencode-health
  5. Backup: $SANDBOX/bin/opencode-backup

Sandbox memakai glibc/Termux asli, tetapi HOME, config, session, cache,
backup, dan socket PTY berada di dalam $SANDBOX.

Hapus total:
  rm -rf "$SANDBOX"
EOF
else
  cat <<'EOF'
Langkah berikutnya:
  1. Jalankan `opencode` sekali, lalu keluar.
     Ini mengunduh helper PTY ke cache.
  2. Jalankan `opencode-repatch`.
  3. Buka lagi dengan `opencode -c`.
  4. Cek dengan `opencode-health`.
  5. Backup opsional: `opencode-backup`.

Setelah `opencode upgrade`, ulangi langkah 1-2.
Restart service dari sesi Termux baru: `opencode service restart`.
EOF
fi
