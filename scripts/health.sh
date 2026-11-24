#!/data/data/com.termux/files/usr/bin/bash
# Read-only health check for OpenCode native on Termux.
set -uo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
TMPDIR="${TMPDIR:-$PREFIX/tmp}"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
BIN="${OPENCODE_BIN:-$HOME/.opencode/bin/opencode}"
LAUNCHER="${OPENCODE_LAUNCHER:-$PREFIX/bin/opencode}"
PTY="${OPENCODE_PTY:-$HOME/.opencode/bin/opencode-pty}"
SOCKET_DIR="${OPENCODE_SOCKET_DIR:-$PREFIX/tmp/oc-pty}"
FAIL=0
WARN=0

section() { printf '\n%s\n' "$*"; }
ok() { printf '  [ OK ] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; WARN=$((WARN + 1)); }
fail() { printf '  [FAIL] %s\n' "$*"; FAIL=$((FAIL + 1)); }
info() { printf '  [info] %s\n' "$*"; }

section "Sistem"
if [ "$(uname -m)" = "aarch64" ]; then
  ok "arsitektur: aarch64"
else
  fail "arsitektur bukan aarch64: $(uname -m)"
fi
if command -v pkg >/dev/null 2>&1; then
  ok "Termux: pkg tersedia"
else
  fail "pkg tidak ditemukan; ini bukan Termux?"
fi
if command -v which >/dev/null 2>&1; then
  ok "which tersedia"
else
  warn "which tidak ada; 'opencode upgrade' bisa gagal (pkg install which)"
fi
info "prefix: $PREFIX"
info "home:   $HOME"
if [ -w "$TMPDIR" ]; then
  ok "TMPDIR writable: $TMPDIR"
else
  fail "TMPDIR tidak writable: $TMPDIR"
fi

section "glibc loader"
if [ -f "$LOADER" ]; then
  ok "loader: $LOADER"
else
  fail "loader tidak ada: $LOADER (pkg install glibc-runner)"
fi

section "Binary OpenCode"
if [ -x "$BIN" ]; then
  ok "binary: $BIN"
  if command -v patchelf >/dev/null 2>&1; then
    GOT="$(patchelf --print-interpreter "$BIN" 2>/dev/null || true)"
    if [ "$GOT" = "$LOADER" ]; then
      ok "interpreter: $GOT"
    else
      fail "interpreter salah: '$GOT' (jalankan opencode-repatch)"
    fi
  else
    warn "patchelf tidak ada; interpreter tidak bisa dicek"
  fi
  if command -v timeout >/dev/null 2>&1; then
    VER="$(timeout 20 "$LAUNCHER" --version 2>&1 | tail -n1)"
    if [ -n "$VER" ] && [ "${VER#*ERROR}" = "$VER" ]; then
      ok "versi: $VER"
    else
      fail "opencode --version gagal: $VER"
    fi
  else
    warn "timeout tidak ada; lewati cek versi"
  fi
else
  fail "binary tidak ada: $BIN (jalankan install.sh)"
fi

section "Launcher"
if [ -x "$LAUNCHER" ]; then
  ok "launcher: $LAUNCHER"
  if grep -q 'OPENCODE_PTY_SOCKET_DIR' "$LAUNCHER" 2>/dev/null; then
    ok "launcher mengatur OPENCODE_PTY_SOCKET_DIR"
  else
    warn "launcher tidak mengatur OPENCODE_PTY_SOCKET_DIR"
  fi
else
  fail "launcher tidak executable: $LAUNCHER"
fi

section "Helper PTY"
if [ -x "$PTY" ]; then
  ok "helper: $PTY"
  if command -v patchelf >/dev/null 2>&1; then
    GOT="$(patchelf --print-interpreter "$PTY" 2>/dev/null || true)"
    if [ "$GOT" = "$LOADER" ]; then
      ok "interpreter helper: $GOT"
    else
      fail "interpreter helper salah: '$GOT' (jalankan opencode-repatch)"
    fi
  fi
else
  warn "helper belum ada; jalankan opencode sekali lalu opencode-repatch"
fi
if [ -d "$SOCKET_DIR" ]; then
  if [ -w "$SOCKET_DIR" ]; then
    ok "socket dir writable: $SOCKET_DIR"
  else
    fail "socket dir tidak writable: $SOCKET_DIR"
  fi
else
  warn "socket dir belum ada: $SOCKET_DIR"
fi

section "Service"
if [ "${OPENCODE_SANDBOX:-0}" = "1" ]; then
  info "sandbox memakai private server (--standalone); cek service dilewati"
elif command -v timeout >/dev/null 2>&1; then
  OUT="$(timeout 25 "$LAUNCHER" service status 2>&1 || true)"
  if printf '%s' "$OUT" | grep -qiE 'running|active|pid|listen|http'; then
    ok "service merespons"
    printf '%s\n' "$OUT" | sed 's/^/         /' | head -n 8
  else
    warn "service belum berjalan atau tidak merespons"
    [ -n "$OUT" ] && printf '%s\n' "$OUT" | sed 's/^/         /' | head -n 5
  fi
else
  warn "timeout tidak ada; lewati cek service"
fi

section "Storage"
AVAIL="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -n "$AVAIL" ]; then
  AVAIL_MB=$((AVAIL / 1024))
  if [ "$AVAIL_MB" -ge 500 ]; then
    ok "free space: ${AVAIL_MB} MB"
  elif [ "$AVAIL_MB" -ge 200 ]; then
    warn "free space rendah: ${AVAIL_MB} MB"
  else
    fail "free space kritis: ${AVAIL_MB} MB"
  fi
else
  warn "tidak bisa membaca free space"
fi
if [ -d "$HOME/.config/opencode" ]; then
  ok "config dir: $HOME/.config/opencode"
else
  warn "config dir belum ada (normal pada instalasi baru)"
fi

section "Ringkasan"
printf '  FAIL: %d   WARN: %d\n' "$FAIL" "$WARN"
if [ "$FAIL" -gt 0 ]; then
  printf '  Ada masalah yang perlu diperbaiki.\n'
  exit 1
fi
if [ "$WARN" -gt 0 ]; then
  printf '  Tidak ada FAIL; warning biasanya tidak fatal.\n'
else
  printf '  Semua pemeriksaan utama lolos.\n'
fi
exit 0
