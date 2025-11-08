#!/usr/bin/env bash
# Day 3 — Log Monitoring (real-time + rate limiting)

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
ALERT_LOG="${LOG_DIR}/alerts_$(date +%Y%m%d).log"
ENV_FILE="${SCRIPT_DIR}/.env"

mkdir -p "$LOG_DIR"

# defaults (can be overridden in .env or CLI)
TARGET_FILE="/var/log/syslog"
PATTERN="error|failed|exception|segfault"
RATE_WINDOW=60        # seconds
RATE_THRESHOLD=5      # max matches per window before we print a 'storm' notice

# Load .env if present
if [[ -f "$ENV_FILE" ]]; then source "$ENV_FILE"; fi
: "${TARGET_FILE:=${TARGET_FILE}}"
: "${PATTERN:=${PATTERN}}"
: "${RATE_WINDOW:=${RATE_WINDOW}}"
: "${RATE_THRESHOLD:=${RATE_THRESHOLD}}"

usage() {
  cat <<USAGE
Usage: ${0##*/} [--file PATH] [--pattern REGEX] [--once] [--help]

Options:
  --file PATH       Log file to monitor (default: ${TARGET_FILE})
  --pattern REGEX   Case-insensitive regex to alert on (default: ${PATTERN})
  --once            Scan current file once (no tail) and exit
  --help            Show this help
Tips:
  Put overrides in .env, e.g.:
    TARGET_FILE="/var/log/auth.log"
    PATTERN="(error|fail|denied)"
USAGE
}

ONCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)    TARGET_FILE="$2"; shift 2;;
    --pattern) PATTERN="$2"; shift 2;;
    --once)    ONCE=1; shift;;
    --help|-h) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1;;
  esac
done

[[ -f "$TARGET_FILE" ]] || { echo "ERROR: File not found: $TARGET_FILE" | tee -a "$ALERT_LOG"; exit 1; }

log_alert() {
  local line="$1"
  printf "[%s] ALERT in %s: %s\n" "$(date '+%F %T')" "$TARGET_FILE" "$line" | tee -a "$ALERT_LOG"
}

storm_notice_printed=0
declare -A bucket
bucket_start=$(date +%s)

process_line() {
  local line="$1"
  if [[ "$line" =~ $PATTERN ]] || echo "$line" | grep -Eiq -- "$PATTERN"; then
    log_alert "$line"

    # rate limiting bucket
    now=$(date +%s)
    if (( now - bucket_start >= RATE_WINDOW )); then
      bucket=()
      bucket_start=$now
      storm_notice_printed=0
    fi
    count=${bucket[match]:-0}
    count=$((count+1))
    bucket[match]=$count

    if (( count > RATE_THRESHOLD )) && (( storm_notice_printed == 0 )); then
      printf "[%s] NOTICE: High alert rate (> %d matches in %ds)\n" \
        "$(date '+%F %T')" "$RATE_THRESHOLD" "$RATE_WINDOW" | tee -a "$ALERT_LOG"
      storm_notice_printed=1
    fi
  fi
}

if (( ONCE )); then
  # Scan current contents only
  while IFS= read -r line; do
    process_line "$line"
  done < "$TARGET_FILE"
  echo "Scan complete. Alerts (if any) in: $ALERT_LOG"
  exit 0
fi

echo "Monitoring: $TARGET_FILE"
echo "Pattern:    $PATTERN"
echo "Writing alerts to: $ALERT_LOG"
echo "Press Ctrl+C to stop."

# Follow new lines in real time
tail -Fn0 "$TARGET_FILE" | while IFS= read -r line; do
  process_line "$line"
done
