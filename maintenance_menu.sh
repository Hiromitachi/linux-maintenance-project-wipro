#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_menu() {
  clear
  echo "========== SYSTEM MAINTENANCE MENU =========="
  echo "1) Run Backup"
  echo "2) System Update & Cleanup"
  echo "3) Monitor Logs (real-time)"
  echo "4) Scan Logs Once"
  echo "5) Exit"
  echo "============================================="
  read -p "Enter choice: " choice
}

run_backup() {
  echo "Running Backup..."
  if [[ -f "$SCRIPT_DIR/backup.sh" ]]; then
    "$SCRIPT_DIR/backup.sh"
  else
    echo "ERROR: backup.sh not found!"
  fi
  read -p "Press Enter to continue..."
}

run_update() {
  echo "Running System Update..."
  if [[ -f "$SCRIPT_DIR/system_update.sh" ]]; then
    "$SCRIPT_DIR/system_update.sh"
  else
    echo "ERROR: system_update.sh not found!"
  fi
  read -p "Press Enter to continue..."
}

monitor_logs() {
  echo "Real-time log monitoring (Ctrl + C to stop)"
  if [[ -f "$SCRIPT_DIR/monitor_logs.sh" ]]; then
    "$SCRIPT_DIR/monitor_logs.sh"
  else
    echo "ERROR: monitor_logs.sh not found!"
  fi
  read -p "Press Enter to continue..."
}

scan_logs_once() {
  echo "Scanning logs once"
  if [[ -f "$SCRIPT_DIR/monitor_logs.sh" ]]; then
    "$SCRIPT_DIR/monitor_logs.sh" --once
  else
    echo "ERROR: monitor_logs.sh not found!"
  fi
  read -p "Press Enter to continue..."
}

while true; do
  show_menu
  case "$choice" in
    1) run_backup ;;
    2) run_update ;;
    3) monitor_logs ;;
    4) scan_logs_once ;;
    5) echo "Exiting..."; exit 0 ;;
    *) echo "Invalid option"; sleep 1 ;;
  esac
done
