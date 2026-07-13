#!/bin/bash

#
# 24IThub VICIdial Inode Recovery Tool
# Version: 1.2.0
#
# Supported:
#   - AlmaLinux 9
#   - VICIdial
#   - MariaDB 10.x
#
# WARNING:
#   This script disables Postfix and deletes pending files from:
#   /var/spool/postfix/maildrop
#

set -u

VERSION="1.2.0"
MAILDROP="/var/spool/postfix/maildrop"
LOG_FILE="/var/log/24ithub-fix-vici.log"

echo "=================================================="
echo "  24IThub VICIdial Inode Recovery Tool v${VERSION}"
echo "=================================================="

# --------------------------------------------------
# Root check
# --------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

# --------------------------------------------------
# Environment validation
# --------------------------------------------------

if [ ! -f /etc/almalinux-release ]; then
    echo "WARNING: AlmaLinux was not detected."
    echo "This tool is designed for AlmaLinux VICIdial servers."
fi

if [ ! -d /usr/share/astguiclient ]; then
    echo "WARNING: VICIdial astguiclient directory was not found."
fi

# --------------------------------------------------
# Logging
# --------------------------------------------------

LOG_ENABLED=0

enable_logging() {
    if touch "$LOG_FILE" 2>/dev/null; then
        LOG_ENABLED=1
    fi
}

log() {
    local MESSAGE
    MESSAGE="[$(date '+%F %T')] $*"

    echo "$MESSAGE"

    if [ "$LOG_ENABLED" -eq 1 ]; then
        echo "$MESSAGE" >> "$LOG_FILE"
    fi
}

inode_usage() {
    df -Pi / | awk 'NR==2 {gsub("%","",$5); print $5}'
}

maildrop_count() {
    if [ -d "$MAILDROP" ]; then
        find "$MAILDROP" -xdev -type f 2>/dev/null | wc -l
    else
        echo 0
    fi
}

# Logging may initially fail when no inodes are available.
enable_logging

log "Recovery started"

echo
echo "Initial disk status:"
df -h /

echo
echo "Initial inode status:"
df -i /

CURRENT_INODES=$(inode_usage)

echo
log "Current inode usage: ${CURRENT_INODES}%"

# --------------------------------------------------
# Stop Postfix before cleanup
# --------------------------------------------------

echo
log "Stopping and disabling Postfix"

systemctl stop postfix >/dev/null 2>&1 || true
systemctl disable postfix >/dev/null 2>&1 || true

# --------------------------------------------------
# Clean Postfix maildrop
# --------------------------------------------------

if [ -d "$MAILDROP" ]; then
    BEFORE=$(maildrop_count)

    log "Postfix maildrop files found: ${BEFORE}"

    if [ "$BEFORE" -gt 0 ]; then
        log "Deleting Postfix maildrop files in batches"

        PASS=1

        while [ "$PASS" -le 10 ]; do
            REMAINING=$(maildrop_count)

            if [ "$REMAINING" -eq 0 ]; then
                break
            fi

            log "Cleanup pass ${PASS}: ${REMAINING} files remaining"

            find "$MAILDROP" -xdev -type f -print0 2>/dev/null |
                xargs -0 -r -n 5000 rm -f

            PASS=$((PASS + 1))
            sleep 1
        done

        # Final retry for files that appeared during cleanup.
        find "$MAILDROP" -xdev -type f -delete 2>/dev/null || true
        sleep 1
        find "$MAILDROP" -xdev -type f -delete 2>/dev/null || true

        AFTER=$(maildrop_count)
        REMOVED=$((BEFORE - AFTER))

        log "Maildrop files removed: ${REMOVED}"
        log "Maildrop files remaining: ${AFTER}"
    else
        log "Postfix maildrop is already empty"
    fi
else
    log "Postfix maildrop directory not found"
fi

echo
echo "Inode status after maildrop cleanup:"
df -i /

FREE_INODES=$(df -Pi / | awk 'NR==2 {print $4}')

if [ "$FREE_INODES" -eq 0 ]; then
    echo
    echo "ERROR: No free inodes are available after cleanup."
    echo "Check other directories containing large numbers of files."
    exit 1
fi

# Logging should now work after inodes have been freed.
enable_logging

# --------------------------------------------------
# Disable cron-generated root email
# --------------------------------------------------

echo
log "Disabling cron email output to root"

for FILE in \
    /etc/crontab \
    /etc/cron.d/0hourly \
    /etc/cron.d/dailyjobs
do
    if [ -f "$FILE" ]; then
        sed -i \
            -e 's/^[[:space:]]*MAILTO=root[[:space:]]*$/MAILTO=""/' \
            -e 's/^[[:space:]]*MAILTO="root"[[:space:]]*$/MAILTO=""/' \
            "$FILE" 2>/dev/null || true
    fi
done

# --------------------------------------------------
# Start MariaDB
# --------------------------------------------------

echo
log "Starting MariaDB"

systemctl reset-failed mariadb >/dev/null 2>&1 || true
systemctl restart mariadb

sleep 5

if systemctl is-active --quiet mariadb; then
    log "MariaDB is running"
else
    log "ERROR: MariaDB failed to start"

    echo
    journalctl -u mariadb -n 50 --no-pager
    exit 1
fi

# --------------------------------------------------
# VICIdial database check and repair
# --------------------------------------------------

if command -v mysqlcheck >/dev/null 2>&1; then
    echo
    log "Checking VICIdial database tables"

    mysqlcheck -u root --check asterisk
    DB_CHECK_STATUS=$?

    if [ "$DB_CHECK_STATUS" -ne 0 ]; then
        echo
        log "Database errors detected; starting automatic repair"

        mysqlcheck -u root --auto-repair asterisk
    else
        log "Initial database check completed successfully"
    fi

    echo
    log "Running final VICIdial database check"

    mysqlcheck -u root --check asterisk
    FINAL_DB_STATUS=$?

    if [ "$FINAL_DB_STATUS" -eq 0 ]; then
        log "VICIdial database check passed"
    else
        log "WARNING: Some database tables still report errors"
    fi
else
    log "WARNING: mysqlcheck command was not found"
fi

# --------------------------------------------------
# Check or start Asterisk
# --------------------------------------------------

echo
log "Checking Asterisk"

if asterisk -rx "core show uptime" >/dev/null 2>&1; then
    log "Asterisk is already running"
else
    log "Asterisk is not responding; attempting to start it"

    if systemctl list-unit-files 2>/dev/null |
        grep -q '^asterisk\.service'; then

        systemctl reset-failed asterisk >/dev/null 2>&1 || true
        systemctl start asterisk >/dev/null 2>&1 || true
    else
        service asterisk start >/dev/null 2>&1 || true
    fi

    sleep 5

    if asterisk -rx "core show uptime" >/dev/null 2>&1; then
        log "Asterisk started successfully"
    else
        log "WARNING: Asterisk is still not responding"
    fi
fi

# --------------------------------------------------
# Start/check Apache
# --------------------------------------------------

echo
log "Checking Apache"

if systemctl is-active --quiet httpd; then
    log "Apache is already running"
else
    systemctl start httpd >/dev/null 2>&1 || true

    if systemctl is-active --quiet httpd; then
        log "Apache started successfully"
    else
        log "WARNING: Apache failed to start"
    fi
fi

# --------------------------------------------------
# Run VICIdial keepalive
# --------------------------------------------------

if [ -f /usr/share/astguiclient/ADMIN_keepalive_ALL.pl ]; then
    echo
    log "Running VICIdial keepalive"

    perl /usr/share/astguiclient/ADMIN_keepalive_ALL.pl \
        --debug >/tmp/24ithub-keepalive.log 2>&1 || true

    sleep 3
else
    log "WARNING: VICIdial keepalive script was not found"
fi

# --------------------------------------------------
# Final cleanup retry
# --------------------------------------------------

if [ -d "$MAILDROP" ]; then
    find "$MAILDROP" -xdev -type f -delete 2>/dev/null || true
    sleep 1
fi

FINAL_MAILDROP=$(maildrop_count)

# --------------------------------------------------
# Final report
# --------------------------------------------------

echo
echo "=================================================="
echo "                 FINAL STATUS"
echo "=================================================="

echo
echo "MariaDB : $(systemctl is-active mariadb 2>/dev/null || echo unknown)"
echo "Postfix : $(systemctl is-active postfix 2>/dev/null || echo unknown)"
echo "Apache  : $(systemctl is-active httpd 2>/dev/null || echo unknown)"

if asterisk -rx "core show uptime" >/dev/null 2>&1; then
    echo "Asterisk: running"
else
    echo "Asterisk: not responding"
fi

echo
echo "Final disk status:"
df -h /

echo
echo "Final inode status:"
df -i /

echo
echo "Postfix maildrop files remaining: ${FINAL_MAILDROP}"

if [ "$FINAL_MAILDROP" -eq 0 ]; then
    log "SUCCESS: Maildrop cleanup completed"
else
    log "WARNING: ${FINAL_MAILDROP} maildrop files still remain"
fi

if systemctl is-active --quiet mariadb; then
    log "SUCCESS: MariaDB is running"
else
    log "ERROR: MariaDB is not running"
fi

echo
echo "Log file: ${LOG_FILE}"
echo "Recovery completed."
