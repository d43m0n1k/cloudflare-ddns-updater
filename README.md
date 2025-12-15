# cloudflare-ddns-updater

A lightweight Bash script to automatically update one or more existing Cloudflare **A records** when your ISP changes your public IPv4 address.

- Logs updates and errors via `journald`
- Sends notifications via **ntfy**
- Designed for homelab / self-hosted environments
- Silent when no changes are needed

---

## How it works

- Checks your current public IPv4 address
- Compares it against existing Cloudflare DNS records
- Updates records **only if the IP has changed**
- Preserves each record’s current `proxied` state
- Sends an ntfy notification only when updates occur

---

## Requirements

- Bash
- `curl`
- `jq`
- Cloudflare account with API access
- 
- Existing A records already created in Cloudflare

---

## Setup

### Create environment file

Create and populate the env file:
```
sudo nano /etc/cloudflare-ddns.env
```

### Cloudflare API Token

Docs: https://developers.cloudflare.com/api/

Use an API Token, not the global API key

Required permissions:

Zone → DNS → Edit

Zone → Read

### ntfy
Project: https://github.com/binwiederhier/ntfy

Optional but recommended for notifications

---

## Copy the script to:
```
/usr/local/bin/cf-ddns-updater-main.sh
```
## Set permissions:
```
sudo chown root:root /usr/local/bin/cf-ddns-updater-main.sh
sudo chmod 750 /usr/local/bin/cf-ddns-updater-main.sh
sudo chown root:root /etc/cloudflare-ddns.env
sudo chmod 600 /etc/cloudflare-ddns.env
```
---

## Edit root’s crontab:
```
sudo crontab -e
```
Add:
```
*/5 * * * * /usr/local/bin/cf-ddns-updater-main.sh
```
---

## Logging & Notifications
No changes → silent
IP change → DNS updated, ntfy notification sent
Error → logged to journald
View logs with:
```
journalctl -t cf-ddns
```
---

#### Notes
This script does not create DNS records

IPv4 only (by design)

Suitable for Cloudflare-proxied or non-proxied records
