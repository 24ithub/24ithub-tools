GOautodial VM clone synchronization
=====================================

Install once on the source VM before exporting it:

  cd /var/www/html
  sudo tools/clone-sync/install.sh

On every boot, goautodial-clone-sync.service detects the primary IPv4 address.
When the VM IP changes it synchronizes:

- MY_IP_ADDR in /etc/kamailio/kamailio.cfg
- interface in /etc/rtpengine/rtpengine.conf
- base_url, GO_agent_domain, GO_agent_wss and GO_agent_wss_sip in IP mode
- kamailio.subscriber.domain
- stale kamailio.location registrations

127.0.0.1, GO_agent_url, Asterisk server IP and phone server IP are never changed.

If GO_agent_domain contains a hostname, domain mode preserves the domain while
Kamailio and RTPengine bind to the new local IP.

Commands
--------

Preview:
  sudo /usr/local/sbin/goautodial-clone-sync --dry-run

Apply now:
  sudo /usr/local/sbin/goautodial-clone-sync

Override auto-detection:
  sudo /usr/local/sbin/goautodial-clone-sync --ip 23.229.7.246

Status:
  systemctl status goautodial-clone-sync.service
  journalctl -u goautodial-clone-sync.service --no-pager

Root-only backups are stored under /root/goautodial-backups/clone-sync/.

TLS note
--------
IP synchronization cannot create a browser-trusted certificate. A self-signed
certificate may need browser trust at https://NEW_IP:4443. The permanent solution
is a domain certificate installed for both Apache and Kamailio WSS.
