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
IPSEC_PSK="${IPSEC_PSK:-}"
CN="comfyconnect"

# Generate a 20-char alphanumeric secret. Read a bounded chunk of /dev/urandom FIRST so no stage
# writes into a closed pipe (piping an endless source into `head` trips SIGPIPE, which `set -o
# pipefail` would turn into a fatal error). Then slice with bash — no pipe-to-head at all.
rand(){ local s; s="$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9')"; printf '%s' "${s:0:20}"; }
# Generate strong random secrets when not supplied. Never ship a guessable default: a weak IPsec
# pre-shared key (e.g. "vpn") is cracked offline in milliseconds and breaks the whole VPN's secrecy.
[ -z "$ADMIN_PW" ] && ADMIN_PW="$(rand)"
[ -z "$IPSEC_PSK" ] && IPSEC_PSK="$(rand)"

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

# Persist the generated secrets to an owner-only file rather than only to the terminal
# (stdout may be captured into a log or CI transcript).
CREDS="./comfyconnect-credentials.txt"
( umask 177
  cat > "$CREDS" <<EOF
ComfyConnect VPN — server credentials (keep private, then delete)
Admin Console : https://${HOST_URL}:5555/admin/
Admin password: ${ADMIN_PW}
Default hub   : ${HUB}
IPsec PSK     : ${IPSEC_PSK}
EOF
)

cat <<EOF

============================================================
  ✅  ComfyConnect VPN Server is up.
============================================================
  Admin Console : https://${HOST_URL}:5555/admin/
                  (or https://${HOST_URL}:443/admin/)
  Default hub   : ${HUB}

  Credentials (admin password + IPsec PSK) were written to:
      $(cd "$(dirname "$CREDS")" && pwd)/$(basename "$CREDS")   (chmod 600)
  Read them with:  cat $CREDS   — then store them in your password manager and delete the file.

  Next steps:
   1. Open the Admin Console above and sign in with the admin password.
   2. Go to Employees → Add employee to create VPN accounts.
   3. Onboard employees with ../onboarding/add-employee.sh (ready-made cards).

  Employees connect to  ${HOST_IP}  using OpenVPN, L2TP/IPsec, or SSTP.

  ⚠  Security: the Admin/management port (5555) is bound to localhost only. Reach the
     console via an SSH tunnel:  ssh -L 5555:127.0.0.1:5555 user@${HOST_IP}
     For production, install a real TLS certificate on the server.
============================================================
EOF
