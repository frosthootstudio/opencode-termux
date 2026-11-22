#!/data/data/com.termux/files/usr/bin/bash
# Re-patch OpenCode and its PTY helper after an upgrade.
# Safe to run at any time; it does not restart the service.
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
BIN="${OPENCODE_BIN:-$HOME/.opencode/bin/opencode}"
LAUNCHER="${OPENCODE_LAUNCHER:-$PREFIX/bin/opencode}"
PTY_BIN="${OPENCODE_PTY:-$HOME/.opencode/bin/opencode-pty}"
STAMP="$HOME/.opencode/bin/.opencode-pty.stamp"
SOCKET_DIR="${OPENCODE_SOCKET_DIR:-$PREFIX/tmp/oc-pty}"

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: opencode-repatch

Re-applies the Termux glibc interpreter to the OpenCode binary and to the
cached PTY helper, then refreshes the launcher.

Run this after:
  opencode upgrade
  opencode        # once, so the new helper is downloaded
EOF
    exit 0
    ;;
esac

command -v patchelf >/dev/null 2>&1 || die "patchelf tidak ada. Jalankan: pkg install patchelf"
[ -x "$BIN" ] || die "Binary tidak ditemukan: $BIN"
[ -f "$LOADER" ] || die "Loader glibc tidak ada: $LOADER (pkg install glibc-runner)"

say "[1/3] Patch binary utama"
BIN_MTIME="$(stat -c %Y "$BIN" 2>/dev/null || echo 0)"
patchelf --set-interpreter "$LOADER" "$BIN"
GOT="$(patchelf --print-interpreter "$BIN")"
[ "$GOT" = "$LOADER" ] || die "Interpreter tidak valid: '$GOT'"
say "      ok: $GOT"

say "[2/3] Siapkan helper PTY stabil"
HELPER_STALE=0
shopt -s nullglob
helpers=("$HOME"/.cache/opencode/bin/opencode-pty/*/opencode-pty)
if [ ${#helpers[@]} -eq 0 ]; then
  say "      (belum ada helper; jalankan opencode sekali, lalu ulangi)"
else
  newest="$(ls -1t "${helpers[@]}" | head -n1)"
  helper_mtime="$(stat -c %Y "$newest" 2>/dev/null || echo 0)"
  if [ "$helper_mtime" -lt "$BIN_MTIME" ]; then
    HELPER_STALE=1
    say "      PERINGATAN: helper di cache lebih tua dari binary."
    say "      Jalankan opencode sekali, keluar, lalu ulangi opencode-repatch."
  fi
  install -m 755 "$newest" "$PTY_BIN"
  patchelf --set-interpreter "$LOADER" "$PTY_BIN"
  GOT="$(patchelf --print-interpreter "$PTY_BIN")"
  [ "$GOT" = "$LOADER" ] || die "Interpreter helper tidak valid: '$GOT'"
  if "$PTY_BIN" --version >/dev/null 2>&1; then
    say "      ok: $PTY_BIN ($("$PTY_BIN" --version 2>/dev/null | head -n1))"
  else
    say "      PERINGATAN: helper tidak bisa dijalankan langsung: $PTY_BIN"
  fi
  say "      sumber: $newest"
fi

say "[3/3] Pastikan launcher"
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

if [ -x "$PTY_BIN" ] && [ "$HELPER_STALE" -eq 0 ]; then
  stat -c '%Y:%s' "$BIN" > "$STAMP"
  say "      stamp:    $STAMP"
else
  rm -f "$STAMP"
  if [ "$HELPER_STALE" -eq 1 ]; then
    say "      stamp tidak ditulis; helper mungkin belum versi baru"
  fi
fi
say "      launcher: $LAUNCHER"
say "      helper:   $PTY_BIN"
say "      socket:   $SOCKET_DIR"

say ""
say "Versi terpasang: $("$LAUNCHER" --version)"
if [ "${OPENCODE_SANDBOX:-0}" = "1" ]; then
  say "Selesai. Sandbox memakai private server; tidak perlu restart service."
else
  say "Selesai. Untuk menerapkan helper PTY, restart service dari sesi Termux lain:"
  say "  opencode service restart"
fi
