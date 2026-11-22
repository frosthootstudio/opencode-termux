#!/data/data/com.termux/files/usr/bin/bash
# Unofficial OpenCode native installer for Termux aarch64.
# No proot, no root, no Ubuntu.
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
TMPDIR="${TMPDIR:-$PREFIX/tmp}"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
BIN_DIR="$HOME/.opencode/bin"
BIN="$BIN_DIR/opencode"
LAUNCHER="$PREFIX/bin/opencode"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${OPENCODE_VERSION:-}"
DRY_RUN=0
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage: bash install.sh [options]

Options:
  --check          Check prerequisites and exit.
  --dry-run        Print planned actions without changing anything.
  --version VER    Install a specific OpenCode version (default: latest).
  -h, --help       Show this help.

Environment:
  OPENCODE_VERSION   Same as --version.
  PREFIX             Termux prefix (auto-detected).
  HOME               Termux home (auto-detected).
EOF
}

say() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
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

if [ "$CHECK_ONLY" -eq 1 ]; then
  say "Pemeriksaan lingkungan"
  info "arch:        $(uname -m)"
  info "prefix:      $PREFIX"
  info "home:        $HOME"
  info "tmpdir:      $TMPDIR"
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
  curl -fL --progress-bar -o "$TMP/opencode.tgz" \
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

say "Menulis launcher"
if [ "$DRY_RUN" -eq 1 ]; then
  info "[dry-run] tulis $LAUNCHER"
else
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
fi

say "Memasang helper"
for name in repatch health backup; do
  src="$HERE/scripts/$name.sh"
  dest="$PREFIX/bin/opencode-$name"
  if [ -f "$src" ]; then
    run install -m 755 "$src" "$dest"
  else
    info "lewati: $src tidak ada"
  fi
done

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
