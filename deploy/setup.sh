#!/usr/bin/env bash
# ComfyConnect VPN — one-command server deployment + configuration.
# Brings up the server, sets the admin password, creates a hub, enables SecureNAT,
# and turns on OpenVPN + L2TP/IPsec so employees can connect. Prints the console URL.
#
#   ./setup.sh                       # interactive-ish, sensible defaults
#   ADMIN_PW=secret HUB=Acme ./setup.sh
set -euo pipefail
cd "$(dirname "$0")"

HUB="${HUB:-ComfyConnect}"
ADMIN_PW="${ADMIN_PW:-}"
IPSEC_PSK="${IPSEC_PSK:-vpn}"
CN="comfyconnect"

rand(){ LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16; }
[ -z "$ADMIN_PW" ] && ADMIN_PW="$(rand)"

echo "▸ Building & starting the ComfyConnect VPN Server (first build takes a few minutes)…"
docker compose up -d --build

echo "▸ Waiting for the server to come online…"
for i in $(seq 1 60); do
  if docker exec "$CN" vpncmd localhost /SERVER /PASSWORD: /CMD ServerInfoGet >/dev/null 2>&1; then break; fi
  sleep 2
  [ "$i" = 60 ] && { echo "Server did not come up in time. Check: docker compose logs"; exit 1; }
done

vc(){ docker exec "$CN" vpncmd localhost /SERVER "$@"; }

echo "▸ Setting the administrator password…"
vc /PASSWORD: /CMD ServerPasswordSet "$ADMIN_PW" >/dev/null

echo "▸ Creating Virtual Hub '$HUB'…"
vc /PASSWORD:"$ADMIN_PW" /CMD HubCreate "$HUB" /PASSWORD:"$(rand)" >/dev/null 2>&1 || echo "  (hub already exists — continuing)"

echo "▸ Enabling SecureNAT (gives employees an IP + internet routing)…"
vc /PASSWORD:"$ADMIN_PW" /ADMINHUB:"$HUB" /CMD SecureNatEnable >/dev/null

echo "▸ Enabling OpenVPN + SSTP…"
vc /PASSWORD:"$ADMIN_PW" /CMD ProtoOptionsSet OpenVPN /NAME:Enabled /VALUE:true >/dev/null 2>&1 \
  || echo "  (could not toggle OpenVPN automatically — enable it in the console)"
vc /PASSWORD:"$ADMIN_PW" /CMD ProtoOptionsSet SSTP /NAME:Enabled /VALUE:true >/dev/null 2>&1 || true

echo "▸ Enabling L2TP/IPsec…"
vc /PASSWORD:"$ADMIN_PW" /CMD IPsecEnable /L2TP:yes /L2TPRAW:no /ETHERIP:no /PSK:"$IPSEC_PSK" /DEFAULTHUB:"$HUB" >/dev/null 2>&1 \
  || echo "  (could not toggle L2TP/IPsec automatically — enable it in the console)"

# Prefer IPv4 for the printed URL; bracket IPv6 if that's all we get.
HOST_IP="$(curl -s -4 --max-time 4 ifconfig.me 2>/dev/null || true)"
[ -z "$HOST_IP" ] && HOST_IP="$(curl -s --max-time 4 ifconfig.me 2>/dev/null || echo YOUR-SERVER-IP)"
case "$HOST_IP" in *:*) HOST_URL="[$HOST_IP]";; *) HOST_URL="$HOST_IP";; esac
cat <<EOF

============================================================
  ✅  ComfyConnect VPN Server is up.
============================================================
  Admin Console : https://${HOST_URL}:5555/admin/
                  (or https://${HOST_URL}:443/admin/)
  Admin password: ${ADMIN_PW}
  Default hub   : ${HUB}
  IPsec PSK     : ${IPSEC_PSK}

  Next steps:
   1. Open the Admin Console above and sign in with the admin password.
   2. Go to Employees → Add employee to create VPN accounts.
   3. Give each employee their username/password and the connection
      details (see ../onboarding/add-employee.sh for ready-made cards).

  Employees connect to  ${HOST_IP}  using:
   • OpenVPN (import the profile), or
   • Built-in Windows/macOS VPN over L2TP/IPsec (PSK: ${IPSEC_PSK}), or
   • SSTP.
============================================================
EOF
