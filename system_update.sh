#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/update_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$LOG_DIR"

log() { 
    printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"; 
}

log "=== System Update Started ==="

log "Updating package lists..."
sudo apt update | tee -a "$LOG_FILE"

log "Upgrading packages..."
sudo apt upgrade -y | tee -a "$LOG_FILE"

log "Removing unused dependencies..."
sudo apt autoremove -y | tee -a "$LOG_FILE"

log "Cleaning apt cache..."
sudo apt clean

log "Clearing thumbnail cache..."
rm -rf ~/.cache/thumbnails/* || true

log "Cleaning system logs older than 7 days..."
sudo find /var/log -type f -mtime +7 -exec rm -f {} \; || true

log "=== System Update Finished ==="
