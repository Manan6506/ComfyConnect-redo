#!/usr/bin/env bash
# ComfyConnect — onboard an employee.
# Creates their VPN account, downloads their OpenVPN profile, and writes a ready-to-send
# connection card. Uses the server's JSON-RPC API (no tools to install besides curl).
#
#   ./add-employee.sh <username> [password]
#
# Config via env:
#   SERVER   VPN server admin URL   (default https://127.0.0.1:5555)
#   ADMIN_PW server admin password  (required)
#   HUB      virtual hub            (default ComfyConnect)
#   HOST     address employees dial (default: derived from SERVER)
set -euo pipefail
cd "$(dirname "$0")"

USER_NAME="${1:-}"
USER_PW="${2:-$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)}"
SERVER="${SERVER:-https://127.0.0.1:5555}"
ADMIN_PW="${ADMIN_PW:-}"
HUB="${HUB:-ComfyConnect}"
HOST="${HOST:-$(echo "$SERVER" | sed -E 's#https?://##; s#:[0-9]+$##')}"

[ -z "$USER_NAME" ] && { echo "Usage: ./add-employee.sh <username> [password]"; exit 1; }
[ -z "$ADMIN_PW" ] && { echo "Set ADMIN_PW to the server administrator password."; exit 1; }

api(){ # method params  -> prints JSON
  curl -sk --max-time 15 -H "X-VPNADMIN-PASSWORD: $ADMIN_PW" -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"$1\",\"params\":$2}" "$SERVER/api/"
}
# Pure-bash contains-check. (Do NOT pipe to grep -q: on a large response grep exits
# early, echo gets SIGPIPE, and `set -o pipefail` then reports the call as failed.)
ok(){ [[ "$1" == *'"result"'* ]]; }

echo "▸ Creating account '$USER_NAME' in hub '$HUB'…"
RES="$(api CreateUser "{\"HubName_str\":\"$HUB\",\"Name_str\":\"$USER_NAME\",\"Realname_utf\":\"$USER_NAME\",\"Note_utf\":\"onboarded via add-employee.sh\",\"AuthType_u32\":1,\"Auth_Password_str\":\"$USER_PW\"}")"
if ! ok "$RES"; then
  # If the user already exists, just (re)set the password.
  echo "  account exists — updating password…"
  RES="$(api SetUser "{\"HubName_str\":\"$HUB\",\"Name_str\":\"$USER_NAME\",\"AuthType_u32\":1,\"Auth_Password_str\":\"$USER_PW\"}")"
  ok "$RES" || { echo "  ERROR: $RES"; exit 1; }
fi

OUT="employee-$USER_NAME"
mkdir -p "$OUT"

echo "▸ Generating OpenVPN profile…"
PROFILE="$(api MakeOpenVpnConfigFile '{}')"
if ok "$PROFILE"; then
  echo "$PROFILE" | python3 -c 'import json,sys,base64; b=json.load(sys.stdin)["result"].get("Buffer_bin",""); sys.stdout.buffer.write(base64.b64decode(b))' > "$OUT/openvpn-profiles.zip"
  echo "  saved $OUT/openvpn-profiles.zip"
else
  echo "  (could not fetch OpenVPN profile — employees can still use L2TP/SSTP)"
fi

cat > "$OUT/CONNECTION-CARD.txt" <<EOF
========================================================
        ComfyConnect VPN — Your Connection Details
========================================================
  Server        : $HOST
  Username      : $USER_NAME
  Password      : $USER_PW
  Virtual Hub   : $HUB

  How to connect (pick one):

  • OpenVPN (recommended)
      1. Install the free OpenVPN Connect app.
      2. Import a profile from openvpn-profiles.zip.
      3. Enter the username and password above.

  • Windows / macOS built-in VPN (L2TP over IPsec)
      Server address : $HOST
      VPN type       : L2TP/IPsec with pre-shared key
      Pre-shared key : (ask your administrator)
      Username / password : as above

  Questions? Contact your IT administrator.
========================================================
EOF

echo "▸ Done. Give the employee the files in ./$OUT/"
echo "   • CONNECTION-CARD.txt   (server, username, password, how-to)"
echo "   • openvpn-profiles.zip  (import into OpenVPN)"
