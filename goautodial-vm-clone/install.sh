#!/bin/bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

SOURCE_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT_SOURCE="$SOURCE_DIR/goautodial-clone-sync"
UNIT_SOURCE="$SOURCE_DIR/goautodial-clone-sync.service"
SCRIPT_TARGET=/usr/local/sbin/goautodial-clone-sync
UNIT_TARGET=/etc/systemd/system/goautodial-clone-sync.service
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR=/root/goautodial-backups/clone-sync-install/$STAMP

[[ -f "$SCRIPT_SOURCE" && -f "$UNIT_SOURCE" ]] || { echo "Clone-sync source files are missing"; exit 1; }
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
if [[ -e "$SCRIPT_TARGET" ]]; then cp -a "$SCRIPT_TARGET" "$BACKUP_DIR/"; fi
if [[ -e "$UNIT_TARGET" ]]; then cp -a "$UNIT_TARGET" "$BACKUP_DIR/"; fi

install -m 0755 "$SCRIPT_SOURCE" "$SCRIPT_TARGET"
install -m 0644 "$UNIT_SOURCE" "$UNIT_TARGET"
systemctl daemon-reload
systemctl enable goautodial-clone-sync.service
"$SCRIPT_TARGET" --dry-run

echo "Installed: $SCRIPT_TARGET"
echo "Enabled: goautodial-clone-sync.service"
echo "Installer backup: $BACKUP_DIR"
echo "Run now if required: $SCRIPT_TARGET"
