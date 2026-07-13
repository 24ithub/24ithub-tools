# 24IThub VICIdial Inode Recovery Tool

A simple recovery utility for VICIdial servers running on AlmaLinux 9.

This script is designed to automatically recover MariaDB startup failures caused by inode exhaustion due to a large Postfix mail queue.

---

## When should I run this script?

Run this tool only if you experience one or more of the following issues:

- MariaDB service fails to start
- VICIdial displays database connection errors
- "No space left on device"
- "Can't create test file"
- "DBI connect failed"
- "Couldn't connect to database"
- Disk space is available, but the server still reports "No space left on device"

---

## Verify Before Running

Check disk space:

```bash
df -h
```

Check inode usage:

```bash
df -i
```

Example of an inode issue:

```
Filesystem      Size Used Avail Use%
/dev/loop1       48G 31G 15G 68%

Filesystem      Inodes   IUsed   IFree IUse%
/dev/loop1      3145728 3145728      0 100%
```

If disk space is available but inode usage is 100%, this script should be used.

---

## What does this script do?

- Detects inode exhaustion
- Stops and disables Postfix
- Cleans the Postfix maildrop queue
- Frees filesystem inodes
- Starts MariaDB
- Checks the VICIdial database
- Repairs database tables if required
- Displays final system status

---

## Supported Platforms

- AlmaLinux 9
- MariaDB 10.x
- VICIdial 2.14

---

## Usage

Download:

```bash
curl -O https://raw.githubusercontent.com/<YOUR_GITHUB_USERNAME>/24ithub-tools/main/fix-vici.sh
```

Make executable:

```bash
chmod +x fix-vici.sh
```

Run:

```bash
sudo ./fix-vici.sh
```

---

## Warning

This tool is intended for emergency recovery only.

It disables Postfix and removes files from the Postfix maildrop queue.

Do not use it on systems where Postfix is actively used for email delivery.

---

## License

MIT License

---

## Author

24IThub LLC

https://24ithub.com
