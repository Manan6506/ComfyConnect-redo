#!/usr/bin/env bash
# ComfyConnect — onboard an employee.
# Creates their VPN account, downloads their OpenVPN profile, and writes a ready-to-send
# connection card. Uses the server's JSON-RPC API (needs curl + python3).
#
#   ./add-employee.sh <username> [password]
#
# Config via env:
#   SERVER   VPN server admin URL   (default https://127.0.0.1:5555)
#   ADMIN_PW server admin password  (required; read from env or prompted — never pass on the CLI)
#   HUB      virtual hub            (default ComfyConnect)
#   HOST     address employees dial (default: derived from SERVER)
set -euo pipefail
umask 077                     # anything we write (cards, profiles, temp files) is owner-only
cd "$(dirname "$0")"

USER_NAME="${1:-}"
# Bounded read then bash-slice — piping endless /dev/urandom into `head` trips SIGPIPE, which
# `set -o pipefail` would make fatal.
rand(){ local s; s="$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9')"; printf '%s' "${s:0:16}"; }
USER_PW="${2:-}"
[ -z "$USER_PW" ] && USER_PW="$(rand)"
SERVER="${SERVER:-https://127.0.0.1:5555}"
ADMIN_PW="${ADMIN_PW:-}"
HUB="${HUB:-ComfyConnect}"
HOST="${HOST:-$(printf '%s' "$SERVER" | sed -E 's#https?://##; s#:[0-9]+$##')}"

[ -z "$USER_NAME" ] && { echo "Usage: ./add-employee.sh <username> [password]"; exit 1; }
# Whitelist the username: it becomes a filesystem path and an account name. Reject anything else.
case "$USER_NAME" in
  *[!A-Za-z0-9._-]*|""|.|..|-*) echo "Invalid username '$USER_NAME' (use only A-Za-z0-9 . _ - )"; exit 1;;
esac
if [ -z "$ADMIN_PW" ]; then
  read -r -s -p "Server administrator password: " ADMIN_PW; echo
  [ -z "$ADMIN_PW" ] && { echo "Password required."; exit 1; }
fi

# Build a JSON-RPC request body SAFELY (python json escapes every value — no string interpolation,
# so a username/password containing quotes can never inject into the request).
build_body(){ # $1=method ; params come from CC_* env vars
  CC_METHOD="$1" python3 - <<'PY'
import json, os
p = {}
for k in ("HubName_str","Name_str","Realname_utf","Note_utf","Auth_Password_str"):
    v = os.environ.get("CC_"+k)
    if v is not None: p[k] = v
if os.environ.get("CC_AuthType_u32"): p["AuthType_u32"] = int(os.environ["CC_AuthType_u32"])
print(json.dumps({"jsonrpc":"2.0","id":"1","method":os.environ["CC_METHOD"],"params":p}))
PY
}

# Call the API. Secrets (admin password header, request body with the user password) are passed to
# curl via a 0600 config file — never on the command line where `ps` could read them.
api(){ # stdin = request body
  local cfg; cfg="$(mktemp)"; chmod 600 "$cfg"
  { printf 'header = "Content-Type: application/json"\n'
    printf 'header = "X-VPNADMIN-PASSWORD: %s"\n' "$ADMIN_PW"
    printf 'data-binary = "@-"\n'; } > "$cfg"
  curl -sk --max-time 15 -K "$cfg" "$SERVER/api/"
  local rc=$?; rm -f "$cfg"; return $rc
}
ok(){ [[ "$1" == *'"result"'* ]]; }   # pure-bash (piping a big body to grep -q trips SIGPIPE under pipefail)

echo "▸ Creating account '$USER_NAME' in hub '$HUB'…"
RES="$(CC_HubName_str="$HUB" CC_Name_str="$USER_NAME" CC_Realname_utf="$USER_NAME" \
       CC_Note_utf="onboarded via add-employee.sh" CC_AuthType_u32=1 CC_Auth_Password_str="$USER_PW" \
       build_body CreateUser | api)"
if ! ok "$RES"; then
  echo "  account exists — updating password…"
  RES="$(CC_HubName_str="$HUB" CC_Name_str="$USER_NAME" CC_AuthType_u32=1 CC_Auth_Password_str="$USER_PW" \
         build_body SetUser | api)"
  ok "$RES" || { echo "  ERROR: $RES"; exit 1; }
fi

OUT="employee-$USER_NAME"
mkdir -p "$OUT"; chmod 700 "$OUT"

echo "▸ Generating OpenVPN profile…"
PROFILE="$(build_body MakeOpenVpnConfigFile | api)"
if ok "$PROFILE"; then
  printf '%s' "$PROFILE" | python3 -c 'import json,sys,base64; b=json.load(sys.stdin)["result"].get("Buffer_bin",""); sys.stdout.buffer.write(base64.b64decode(b))' > "$OUT/openvpn-profiles.zip"
  chmod 600 "$OUT/openvpn-profiles.zip"
  echo "  saved $OUT/openvpn-profiles.zip"
else
  echo "  (could not fetch OpenVPN profile — employees can still use L2TP/SSTP)"
fi

umask 177
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

  Keep this file private — it contains a password. Delete it after the employee connects.
========================================================
EOF
chmod 600 "$OUT/CONNECTION-CARD.txt"

echo "▸ Done. Files (owner-readable only) are in ./$OUT/"
echo "   • CONNECTION-CARD.txt   (server, username, password, how-to)"
echo "   • openvpn-profiles.zip  (import into OpenVPN)"
echo "   Send them over a secure channel, then delete your local copies."
