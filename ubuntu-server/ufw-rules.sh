#!/usr/bin/env bash
# Run once as root to (re)build the rule set. Review the variables first.
# Default-deny firewall for a single-purpose server on its own VLAN.
# The app's own ports are explicitly denied so they can only be reached through the SSH tunnel.
set -euo pipefail

MGMT_NET="192.168.10.0/24"  # management VLAN
VPN_NET="10.8.0.0/24"       # remote-access VPN clients
HUB_IP="192.168.40.20"      # the one device allowed to talk to the app on this VLAN

ufw --force reset
ufw default deny incoming
ufw default allow outgoing      # updates, signature downloads

ufw allow from "$MGMT_NET" to any port 22 proto tcp comment 'SSH from management'
ufw allow from "$VPN_NET"  to any port 22 proto tcp comment 'SSH from VPN'

# Never expose the app's admin/API ports directly.
for p in 10443 11080 10081; do
  ufw deny "$p" comment 'app admin port, tunnel only'
done

# Hub device: only the narrow ports the integration needs.
ufw allow from "$HUB_IP" to any port 43220:43229 proto tcp comment 'hub: accessory ports'
ufw allow from "$HUB_IP" to any port 32768:65535 proto udp comment 'hub: media streams'
ufw allow from "$HUB_IP" to any port 5353 proto udp comment 'hub: mDNS'
ufw allow from "$HUB_IP" to any port 50000:53999 proto tcp comment 'hub: recording data (pinned ephemeral range)'

ufw logging medium
ufw --force enable
ufw status numbered
