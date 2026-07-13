#!/bin/bash

set -u

VERSION="1.1.0"
MAILDROP="/var/spool/postfix/maildrop"
LOG_FILE="/var/log/24ithub-fix-vici.log"
INODE_TRIGGER=90

echo "=================================================="
echo "  24IThub VICIdial Inode Recovery Tool v${VERSION}"
echo "=================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
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

log "Recovery started"

CURRENT_INODES=$(inode_usage)

echo
echo "Current inode status:"
df -i /

echo
log "Current inode usage: ${CURRENT_INODES}%"

echo
log "Stopping and disabling Postfix"

systemctl stop postfix 2>/dev/null || true
systemctl disable postfix 2>/dev/null || true
systemctl mask postfix 2>/dev/null || true

if [ -d "$MAILDROP" ]; then
    BEFORE=$(maildrop_count)

    log "Postfix maildrop files found: ${BEFORE}"

    if [ "$BEFORE" -gt 0 ]; then
        log "Cleaning Postfix maildrop in batches"

        PASS=0

        while true; do
            PASS=$((PASS + 1))
            REMAINING=$(maildrop_count)

            if [ "$REMAINING" -eq 0 ]; then
                break
            fi

            log "Cleanup pass ${PASS}: ${REMAINING} files remaining"

            find "$MAILDROP" -xdev -type f -print0 2>/dev/null |
                xargs -0 -r -n 5000 rm -f

            sleep 1

            if [ "$PASS" -ge 1000 ]; then
                log "ERROR: Cleanup safety limit reached"
                break
            fi
        done

        AFTER=$(maildrop_count)
        REMOVED=$((BEFORE - AFTER))

        log "Maildrop cleanup completed"
        log "Files removed: ${REMOVED}"
        log "Files remaining: ${AFTER}"
    else
        log "Maildrop is already empty"
    fi
else
    log "Postfix maildrop directory not found"
fi

echo
echo "Inode status after cleanup:"
df -i /

FREE_INODES=$(df -Pi / | awk 'NR==2 {print $4}')

if [ "$FREE_INODES" -eq 0 ]; then
    log "ERROR: No free inodes available after cleanup"
    exit 1
fi

log "Disabling cron email output"

for FILE in \
    /etc/crontab \
    /etc/cron.d/0hourly \
    /etc/cron.d/dailyjobs
do
    if [ -f "$FILE" ]; then
        sed -i \
            -e 's/^[[:space:]]*MAILTO=root[[:space:]]*$/MAILTO=""/' \
            -e 's/^[[:space:]]*MAILTO="root"[[:space:]]*$/MAILTO=""/' \
            "$FILE"
    fi
done

log "Starting MariaDB"

systemctl reset-failed mariadb 2>/dev/null || true
systemctl restart mariadb

sleep 5

if systemctl is-active --quiet mariadb; then
    log "MariaDB is running"

    echo
    log "Checking VICIdial database tables"

    mysqlcheck -u root --check asterisk
    CHECK_STATUS=$?

    if [ "$CHECK_STATUS" -ne 0 ]; then
        log "Table errors detected; running auto-repair"
        mysqlcheck -u root --auto-repair asterisk
    else
        log "Initial database check completed"
        log "Running auto-repair for any tables marked as crashed"
        mysqlcheck -u root --auto-repair asterisk
    fi

    echo
    log "Rechecking VICIdial database"

    mysqlcheck -u root --check asterisk
    FINAL_DB_STATUS=$?

    if [ "$FINAL_DB_STATUS" -eq 0 ]; then
        log "VICIdial database check passed"
    else
        log "WARNING: Some database tables still report errors"
    fi
else
    log "ERROR: MariaDB failed to start"

    journalctl -u mariadb -n 30 --no-pager
fi

echo
log "Starting VICIdial keepalive"

/usr/bin/perl \
    /usr/share/astguiclient/ADMIN_keepalive_ALL.pl \
    --debug >/tmp/24ithub-keepalive.log 2>&1 || true

sleep 3

echo
echo "Final service status:"
echo "MariaDB : $(systemctl is-active mariadb 2>/dev/null)"
echo "Postfix : $(systemctl is-active postfix 2>/dev/null)"
echo "Asterisk: $(systemctl is-active asterisk 2>/dev/null)"
echo "Apache  : $(systemctl is-active httpd 2>/dev/null)"

echo
echo "Final inode status:"
df -i /

FINAL_MAILDROP=$(maildrop_count)

echo
echo "Postfix maildrop files remaining: ${FINAL_MAILDROP}"

if [ "$FINAL_MAILDROP" -eq 0 ]; then
    log "SUCCESS: Recovery completed and maildrop is empty"
else
    log "WARNING: ${FINAL_MAILDROP} maildrop files still remain"
fi

echo
echo "Log file: ${LOG_FILE}"
echo "Recovery completed."
