# 24IThub VICIdial Inode Recovery Tool

A lightweight recovery tool for **VICIdial servers running on AlmaLinux 9**.

This utility automatically recovers MariaDB startup failures caused by **inode exhaustion**, usually triggered by millions of files accumulating in the Postfix maildrop queue.

---

# 🚀 Quick Run

Run the latest version directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/24ithub/24ithub-tools/main/fix-vici.sh | bash
```

No installation required.

---

# Features

- Detects inode exhaustion
- Stops and disables Postfix
- Cleans Postfix maildrop queue
- Frees filesystem inodes
- Starts MariaDB
- Checks VICIdial database
- Repairs crashed database tables
- Verifies database integrity
- Starts Asterisk (if required)
- Starts Apache (if required)
- Executes VICIdial KeepAlive
- Generates recovery log
- Displays complete system health report

---

# When should I run this tool?

Run this tool only if your server shows one or more of the following symptoms:

- MariaDB fails to start
- VICIdial cannot connect to database
- DBI connect failed
- Couldn't connect to database
- No space left on device
- Can't create test file
- MariaDB exits with Result: resources
- Disk space is available but new files cannot be created
- Filesystem inode usage reaches 100%

---

# Verify Before Running

Check available disk space:

```bash
df -h
```

Check inode usage:

```bash
df -i
```

Example:

```text
Filesystem      Size Used Avail Use%
/dev/loop1       48G 31G 15G 68%

Filesystem      Inodes   IUsed   IFree IUse%
/dev/loop1      3145728 3145728      0 100%
```

If **disk space is available** but **inode usage is 100%**, run the recovery tool.

---

# What does this tool do?

The recovery process automatically:

1. Validates the environment
2. Checks inode usage
3. Stops Postfix
4. Removes Postfix maildrop files
5. Frees filesystem inodes
6. Starts MariaDB
7. Checks the VICIdial database
8. Repairs supported crashed tables
9. Verifies database integrity
10. Starts Asterisk if necessary
11. Starts Apache if necessary
12. Executes VICIdial KeepAlive
13. Generates a final health report

---

# Supported Platforms

- AlmaLinux 9
- VICIdial 2.14
- MariaDB 10.x
- Asterisk
- Apache HTTP Server
- Postfix

---

# Recovery Log

The tool automatically generates:

```text
/var/log/24ithub-fix-vici.log
```

---

# Expected Successful Output

```text
MariaDB : active
Apache  : active
Asterisk: running
Postfix : inactive

Postfix maildrop files remaining: 0

SUCCESS: Maildrop cleanup completed
SUCCESS: MariaDB is running

Recovery completed.
```

---

# Manual Verification

MariaDB

```bash
systemctl status mariadb --no-pager
```

Asterisk

```bash
asterisk -rx "core show uptime"
```

Apache

```bash
systemctl status httpd --no-pager
```

VICIdial Screens

```bash
screen -ls
```

Maildrop Queue

```bash
find /var/spool/postfix/maildrop -type f | wc -l
```

Inode Usage

```bash
df -i
```

---

# Warning

This tool performs the following actions:

- Stops Postfix
- Disables Postfix
- Deletes all files from

```text
/var/spool/postfix/maildrop
```

- Disables cron emails sent to the root user

Do **NOT** run this tool on servers that actively use Postfix for:

- Customer email delivery
- Password reset emails
- Voicemail-to-email
- Application email
- Scheduled reports
- Alert notifications

---

# Database Repair

The tool automatically runs:

```bash
mysqlcheck -u root --check asterisk
mysqlcheck -u root --auto-repair asterisk
```

Some MEMORY or unsupported storage engines may display informational messages during checks. This does not necessarily indicate corruption.

---

# Repository

GitHub Repository

https://github.com/24ithub/24ithub-tools

Latest Script

```text
https://raw.githubusercontent.com/24ithub/24ithub-tools/main/fix-vici.sh
```

Run Directly

```bash
curl -fsSL https://raw.githubusercontent.com/24ithub/24ithub-tools/main/fix-vici.sh | bash
```

---

# License

MIT License

---

# Author

**24IThub LLC**

Website

https://24ithub.com
