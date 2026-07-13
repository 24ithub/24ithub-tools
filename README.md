# 24IThub VICIdial Inode Recovery Tool

A recovery and maintenance utility for VICIdial servers running on AlmaLinux 9.

This tool repairs a common VICIdial server issue where MariaDB fails to start because the filesystem has exhausted all available inodes, even though several gigabytes of disk space may still be free.

The most common cause addressed by this tool is an abnormally large Postfix maildrop queue containing millions of small files.

---

## When should this tool be used?

Run this tool when the server shows symptoms such as:

- MariaDB fails to start
- VICIdial displays database connection errors
- `No space left on device`
- `Can't create test file`
- `DBI connect failed`
- `Couldn't connect to database`
- MariaDB reports `Result: resources`
- Disk space is available, but services cannot create new files
- VICIdial keepalive cannot connect to MariaDB

Example MariaDB error:

```text
Can't create test file '/var/lib/mysql/server.lower-test'
Errcode: 28 "No space left on device"
```

---

## Verify the issue before running

Check normal disk usage:

```bash
df -h
```

Check inode usage:

```bash
df -i
```

Example of inode exhaustion:

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/loop1       48G   31G   15G  68% /

Filesystem       Inodes   IUsed IFree IUse% Mounted on
/dev/loop1      3145728 3145728     0  100% /
```

In this example, the server still has 15 GB of disk space available, but no free inodes remain.

---

## What does the tool do?

The script performs the following recovery actions:

- Verifies that it is running as root
- Displays disk and inode usage
- Stops and disables Postfix
- Counts files in the Postfix maildrop queue
- Deletes Postfix maildrop files in safe batches
- Retries cleanup until the queue is empty
- Disables cron email output to the root user
- Starts MariaDB
- Checks the VICIdial `asterisk` database
- Automatically repairs supported crashed tables
- Runs a final database verification
- Checks and starts Asterisk when required
- Checks and starts Apache
- Runs the VICIdial keepalive script
- Displays the final health status
- Saves a recovery log

Recovery log:

```text
/var/log/24ithub-fix-vici.log
```

---

## Supported platforms

Tested and designed for:

- AlmaLinux 9
- VICIdial 2.14 and compatible installations
- MariaDB 10.x
- Asterisk
- Apache HTTP Server
- Postfix

---

## Quick run

Run the latest version directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/24ithub/24ithub-tools/main/fix-vici.sh | bash
```

The command must be run as the root user.

---

## Download and run locally

Download the script:

```bash
curl -O https://raw.githubusercontent.com/24ithub/24ithub-tools/main/fix-vici.sh
```

Make it executable:

```bash
chmod +x fix-vici.sh
```

Run it:

```bash
./fix-vici.sh
```

---

## Expected successful result

A successful recovery should show:

```text
MariaDB : active
Postfix : inactive
Apache  : active
Asterisk: running

Postfix maildrop files remaining: 0
SUCCESS: Maildrop cleanup completed
SUCCESS: MariaDB is running
Recovery completed.
```

The inode usage should also fall significantly:

```text
Before: 100%
After : 5% to 20%
```

Actual values depend on the server and installed files.

---

## Important warning

This script:

- Disables Postfix
- Deletes pending files from `/var/spool/postfix/maildrop`
- Disables cron email output addressed to the root user

Do not run this tool on a server that actively depends on Postfix for:

- Customer email delivery
- Scheduled report emails
- Voicemail-to-email delivery
- Password reset emails
- System alerts
- Application email delivery

Pending Postfix maildrop messages are permanently deleted.

Review the script before running it on a production server.

---

## Database repair limitations

The tool uses:

```bash
mysqlcheck -u root --check asterisk
mysqlcheck -u root --auto-repair asterisk
```

Automatic repair mainly applies to supported MyISAM tables.

Some tables may display:

```text
The storage engine for the table doesn't support check
```

This is normally informational for MEMORY or other unsupported table engines and does not automatically indicate corruption.

Severe InnoDB corruption requires a separate recovery procedure.

---

## Manual verification

Check MariaDB:

```bash
systemctl status mariadb --no-pager
```

Check Asterisk:

```bash
asterisk -rx "core show uptime"
```

Check Apache:

```bash
systemctl status httpd --no-pager
```

Check VICIdial processes:

```bash
screen -ls
```

Check remaining Postfix maildrop files:

```bash
find /var/spool/postfix/maildrop -type f | wc -l
```

Check inodes:

```bash
df -i
```

---

## Repository

Source code:

```text
https://github.com/24ithub/24ithub-tools
```

Raw script:

```text
https://raw.githubusercontent.com/24ithub/24ithub-tools/main/fix-vici.sh
```

---

## Security

Never add the following information to this public repository:

- Database passwords
- SIP passwords
- API keys
- Customer information
- Server IP addresses
- Private certificates
- License keys
- Authentication tokens

---

## License

MIT License

---

## Author

**24IThub LLC**

Website:

```text
https://24ithub.com
```
