# linux-hardening

Hardening configs from two builds: a headless Ubuntu Server 24.04 box that runs a containerized home-security app on an isolated VLAN, and a Kali Linux laptop used as a field workstation. Each file says in its first lines where it goes on the system and why.

IP ranges, MAC addresses, ports and usernames are placeholders. Swap in your own before using anything here.

## ubuntu-server

A single-purpose server: one Docker container, reachable for admin only over SSH, on a VLAN that only one other device can talk to. Lynis hardening index went from 68 to 76 with zero warnings.

| Area | What's in place | File |
|---|---|---|
| SSH | Keys only, from a YubiKey PIV slot. One user, allowed only from the management VLAN and the VPN subnet. The only port forward allowed is the tunnel to the app's admin page, so that page is never exposed on the network. | `sshd-hardening.conf` |
| Firewall | UFW default deny. SSH from two subnets. The app's admin ports are explicitly denied. One hub device gets only the ports the integration needs. | `ufw-rules.sh` |
| Narrow ephemeral ports | The kernel's ephemeral port range is pinned to 50000-53999, so the firewall can allow that window to the hub instead of 28,000 ports. | `sysctl-97-portrange.conf` |
| Brute force | fail2ban on sshd (5 failures in 10 minutes = 30 minute ban), with the management VLAN never banned so there's always a way back in. | `fail2ban-sshd.local` |
| Auditing | auditd watches identity files, sudoers, SSH and firewall config, systemd units, cron, Docker, root command execution by real users and kernel module loads. Rules are locked until reboot. | `auditd-hardening.rules` |
| Kernel | Restricted kernel pointers and dmesg, ptrace limited, unprivileged BPF off, kexec off, reverse-path filtering, no redirects or source routing, SYN cookies. IPv6 off (not used on this VLAN). | `sysctl-98-hardening.conf`, `sysctl-99-noipv6.conf` |
| Modules | Unused network protocols (DCCP, SCTP, RDS, TIPC) and USB storage can't load. | `modprobe-blacklist.conf` |
| ARP | Static ARP entries for the gateway and the hub, so neither can be spoofed on the LAN. | `arp-pin@.service`, `arp-pin` |
| Malware | rkhunter daily with a zero-warning baseline. ClamAV signatures auto-update; a full scan runs every Sunday. | `rkhunter.conf.local`, `clamscan-weekly.service`, `clamscan-weekly.timer` |

Also done on the box, not shown as files: Docker in host network mode so UFW applies to the container, Postfix removed, core dumps off, umask 027, a login banner, and IPv6 disabled in netplan as well as sysctl.

## kali-workstation

A laptop that goes on untrusted networks. The focus is on not trusting the local network at all: its DNS, its ARP and its Wi-Fi names.

| Area | What's in place | File |
|---|---|---|
| Inbound | nftables input policy drop. Only replies, loopback, DHCP and the ICMP needed for the network to work. | `nftables-hardening.nft` |
| DNS lockdown | Plain DNS (port 53) can only go to the local resolver. Anything else trying to use the network's DNS is rejected. | `nftables-hardening.nft` |
| Encrypted DNS | dnscrypt-proxy to Quad9's malware-filtering resolver, DNSSEC required, using the signed public resolver list. | `dnscrypt-proxy.toml` |
| VPN kill switch | If the WireGuard tunnel is down, nothing leaves the machine except the handshake to the VPN server and DHCP. | `nftables-vpn-killswitch.nft` |
| Wi-Fi | A NetworkManager dispatcher hook turns off auto-connect on every Wi-Fi profile, so the laptop never joins a look-alike network by name. | `nm-dispatcher-90-no-autoconnect` |
| SSH | The service stays off, but the config is hardened in case it's ever turned on. fail2ban is set up with the nftables backend. | `sshd-hardening.conf`, `fail2ban-sshd.local` |
| Updates | Downloaded automatically, installed by hand. A rolling distro shouldn't upgrade itself unattended. | `apt-20auto-upgrades` |
| USB | USB storage blocked. YubiKeys still work. | `modprobe-usb-storage.conf` |

Also running on the laptop: auditd, chkrootkit, arpwatch (alerts on ARP changes, which is how ARP poisoning shows up), Snort on the Wi-Fi and VPN interfaces, and avahi-daemon masked.

## How these were checked

- `sshd -t` on both SSH configs, with `sshd -T` to confirm the effective settings
- `fail2ban-client -t` on both jails
- `nft -c -f` on both nftables rule sets
- `systemd-analyze verify` on the units, and `systemd-analyze calendar` on the scan schedule
- `shellcheck` on every script
- `auditctl` parsing each audit rule
- The DNSCrypt resolver list's signature verified against the key in the config

## License

MIT
