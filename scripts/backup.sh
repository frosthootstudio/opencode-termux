#!/data/data/com.termux/files/usr/bin/bash
# Backup OpenCode config/state. Session DB is opt-in because it may contain
# credentials.
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
TMPDIR="${TMPDIR:-$PREFIX/tmp}"
CONFIG="$HOME/.config/opencode"
STATE="$HOME/.local/state/opencode"
DATA="$HOME/.local/share/opencode"
OUT="${OPENCODE_BACKUP_DIR:-$HOME/.opencode/backups}"
KEEP=7
WITH_DB=0
ENCRYPT=0

usage() {
  cat <<'EOF'
Usage: opencode-backup [options]

Options:
  --with-db        Include the session database (may contain credentials).
  --encrypt        Encrypt the archive with GPG symmetric AES-256.
  --output DIR     Output directory (default: ~/.opencode/backups).
  --keep N         Keep the newest N archives (default: 7, 0 = keep all).
  -h, --help       Show this help.

Environment:
  OPENCODE_BACKUP_DIR                 Default output directory.
  OPENCODE_BACKUP_PASSPHRASE_FILE    Non-interactive GPG passphrase file.
EOF
}

say() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --with-db) WITH_DB=1; shift ;;
    --encrypt) ENCRYPT=1; shift ;;
    --output)
      [ $# -ge 2 ] || die "--output butuh direktori"
      OUT="$2"
      shift 2
      ;;
    --keep)
      [ $# -ge 2 ] || die "--keep butuh angka"
      KEEP="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "Opsi tidak dikenal: $1" ;;
  esac
done

case "$KEEP" in
  ''|*[!0-9]*) die "--keep harus angka 0 atau lebih" ;;
esac

mkdir -p "$OUT"
chmod 700 "$OUT" 2>/dev/null || true
STAMP="$(date +%Y%m%d-%H%M%S)"
BASE="$OUT/opencode-backup-$STAMP"
STAGE="$(mktemp -d "$TMPDIR/opencode-backup.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

mkdir -p "$STAGE/config" "$STAGE/state" "$STAGE/data"

if [ -d "$CONFIG" ]; then
  cp -a "$CONFIG" "$STAGE/config/opencode"
  find "$STAGE/config/opencode" -type f -print0 2>/dev/null \
    | while IFS= read -r -d '' file; do
        base="$(basename "$file")"
        case "$base" in
          *.env.example) ;;
          *.env|*.env.*|service.json|*.key|*.pem|id_*|backup.pass)
            rm -f "$file"
            ;;
        esac
      done
fi

if [ -d "$STATE" ]; then
  cp -a "$STATE" "$STAGE/state/opencode"
fi

if [ "$WITH_DB" -eq 1 ]; then
  DB="$DATA/opencode.db"
  if [ -f "$DB" ]; then
    if command -v sqlite3 >/dev/null 2>&1; then
      sqlite3 "$DB" ".backup '$STAGE/data/opencode.db'"
    else
      cp -a "$DB" "$STAGE/data/opencode.db"
      [ -f "$DB-wal" ] && cp -a "$DB-wal" "$STAGE/data/opencode.db-wal"
      [ -f "$DB-shm" ] && cp -a "$DB-shm" "$STAGE/data/opencode.db-shm"
    fi
    chmod 600 "$STAGE/data/opencode.db" 2>/dev/null || true
  else
    say "Catatan: database sesi tidak ditemukan."
  fi
fi

ARCHIVE="$BASE.tar.gz"
tar -czf "$ARCHIVE" -C "$STAGE" .
chmod 600 "$ARCHIVE"

if [ "$ENCRYPT" -eq 1 ]; then
  command -v gpg >/dev/null 2>&1 || die "gpg tidak ada. Jalankan: pkg install gnupg"
  if [ -n "${OPENCODE_BACKUP_PASSPHRASE_FILE:-}" ]; then
    [ -f "$OPENCODE_BACKUP_PASSPHRASE_FILE" ] || die "passphrase file tidak ada"
    gpg --batch --yes --symmetric --cipher-algo AES256 \
      --passphrase-file "$OPENCODE_BACKUP_PASSPHRASE_FILE" \
      --output "$ARCHIVE.gpg" "$ARCHIVE"
  else
    gpg --symmetric --cipher-algo AES256 --output "$ARCHIVE.gpg" "$ARCHIVE"
  fi
  rm -f "$ARCHIVE"
  ARCHIVE="$ARCHIVE.gpg"
  chmod 600 "$ARCHIVE"
fi

if [ "$KEEP" -gt 0 ]; then
  mapfile -t old < <(ls -1t "$OUT"/opencode-backup-* 2>/dev/null | tail -n +$((KEEP + 1)) || true)
  for file in "${old[@]:-}"; do
    [ -n "$file" ] && rm -f "$file"
  done
fi

say "Backup selesai: $ARCHIVE"
say "Ukuran: $(du -h "$ARCHIVE" | awk '{print $1}')"
say "Isi: config + state$([ "$WITH_DB" -eq 1 ] && echo ' + session DB')"
if [ "$WITH_DB" -eq 1 ]; then
  say "PERINGATAN: database sesi dapat berisi kredensial. Simpan backup ini privat."
fi
if [ "$ENCRYPT" -eq 0 ]; then
  say "Backup tidak terenkripsi. Gunakan --encrypt untuk backup terenkripsi."
fi
