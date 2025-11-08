#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/backup_$(date +%Y%m%d).log"
ENV_FILE="${SCRIPT_DIR}/.env"
EXCLUDE_FILE="${SCRIPT_DIR}/exclude.txt"

mkdir -p "$LOG_DIR"

log()  { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"; }
die()  { log "ERROR: $*"; exit 1; }

usage() {
  cat <<USAGE
Usage: ${0##*/} [--dry-run] [--help]

Options:
  --dry-run   Show actions without creating backup
  --help      Show this help message
USAGE
}

# Load config
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
else
  die "Missing .env file"
fi

# Set defaults if not provided
: "${SRC_DIR:="$HOME/Documents"}"
: "${DEST_DIR:="$HOME/backups"}"
: "${RETAIN:=5}"
: "${ALWAYS_DRY_RUN:=0}"

# Parse arguments
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown argument: $arg" ;;
  esac
done

if [[ "$ALWAYS_DRY_RUN" -eq 1 ]]; then
  DRY_RUN=1
fi

[[ -d "$SRC_DIR" ]] || die "SRC_DIR does not exist: $SRC_DIR"
mkdir -p "$DEST_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_NAME="backup_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${DEST_DIR}/${ARCHIVE_NAME}"

log "=== Backup started ==="
log "Source:      $SRC_DIR"
log "Destination: $DEST_DIR"
log "Archive:     $ARCHIVE_PATH"

# Build tar command
TAR_CMD=(tar -czf "$ARCHIVE_PATH" -C "$SRC_DIR" .)

if [[ -s "$EXCLUDE_FILE" ]]; then
  TAR_CMD=(tar --exclude-from="$EXCLUDE_FILE" -czf "$ARCHIVE_PATH" -C "$SRC_DIR" .)
  log "Using exclude patterns"
fi

# Dry run or real run
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[DRY-RUN] Would run: ${TAR_CMD[*]}"
  (cd "$SRC_DIR" && find . -type f | head -n 20)
else
  "${TAR_CMD[@]}"
  log "Archive created: $ARCHIVE_PATH"
fi

# Rotation: keep last N
archives=( $(ls -1t "$DEST_DIR"/backup_*.tar.gz 2>/dev/null || true) )
count=${#archives[@]}
if (( count > RETAIN )); then
  to_delete=( "${archives[@]:RETAIN}" )
  for f in "${to_delete[@]}"; do
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "[DRY-RUN] Would remove: $f"
    else
      rm "$f"
      log "Removed old backup: $f"
    fi
  done
fi

log "=== Backup finished ==="
