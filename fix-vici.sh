#!/bin/bash

echo "=========================================="
echo "  24IThub VICIdial Inode Recovery Tool"
echo "=========================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

INODE_USE=$(df -Pi / | awk 'NR==2 {gsub("%","",$5); print $5}')

echo "Current inode usage: ${INODE_USE}%"

if [ "$INODE_USE" -ge 90 ]; then
    echo "Stopping and disabling Postfix..."
    systemctl stop postfix 2>/dev/null
    systemctl disable postfix 2>/dev/null

    MAILDROP="/var/spool/postfix/maildrop"

    if [ -d "$MAILDROP" ]; then
        BEFORE=$(find "$MAILDROP" -type f 2>/dev/null | wc -l)
        echo "Maildrop files found: $BEFORE"
        echo "Deleting Postfix maildrop files..."
        find "$MAILDROP" -type f -delete 2>/dev/null
    else
        echo "Postfix maildrop directory not found."
    fi
else
    echo "Inode usage is below 90%. Skipping maildrop cleanup."
fi

echo "Disabling cron email output..."

for FILE in \
    /etc/crontab \
    /etc/cron.d/0hourly \
    /etc/cron.d/dailyjobs
do
    if [ -f "$FILE" ]; then
        sed -i 's/^MAILTO=root/MAILTO=""/' "$FILE" 2>/dev/null
    fi
done

echo "Starting MariaDB..."
systemctl restart mariadb

sleep 3

if systemctl is-active --quiet mariadb; then
    echo "MariaDB: RUNNING"

    echo
    echo "Checking VICIdial database tables..."
    mysqlcheck -u root --check asterisk

    echo
    echo "Repairing crashed VICIdial tables..."
    mysqlcheck -u root --auto-repair asterisk

    echo
    echo "Rechecking VICIdial database..."
    mysqlcheck -u root --check asterisk
else
    echo "MariaDB: FAILED"
    echo "Database repair skipped because MariaDB is not running."
fi

echo
echo "Final inode status:"
df -i /

echo
echo "Recovery completed."
