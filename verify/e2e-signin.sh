#!/usr/bin/env bash
# e2e-signin.sh — complete the RFC 8628 device flow against the gateway+Dex and
# emit a gateway access token to /tmp/gw_token.txt.
#
# Sign-in path: curl-scripted redirect chain (NOT agent-browser). The internal
# ALB is private (RFC1918 only) so we run from this in-VPC EC2 host, which
# resolves gw.claude-gateway.internal to the ALB's private IP. Documented as the
# vantage point per the phase spec.
#
# Flow:
#   1. POST /oauth/device_authorization        -> device_code + user_code
#   2. GET  /device?user_code=...              -> confirm page (warms cookies)
#   3. POST /device (same-origin headers)      -> 302 to Dex /dex/auth
#   4. GET  (follow) -> /dex/auth/local/login  -> Dex login form
#   5. POST /dex/auth/local/login (creds)      -> Dex approves -> /oauth/callback
#   6. follow callback -> gateway marks the device approved
#   7. poll POST /oauth/token (device_code grant) -> access_token
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CA="${ROOT}/certs/ca.pem"
H="${GATEWAY_URL:-https://gw.claude-gateway.internal}"
EMAIL="${DEV_EMAIL:-dev@example.com}"
PASSWORD="${DEV_PASSWORD:-gateway-dev-pw}"
CJ="$(mktemp)"
trap 'rm -f "$CJ"' EXIT

cfetch() { curl -sS --cacert "$CA" -c "$CJ" -b "$CJ" "$@"; }

echo ">> [1] device_authorization"
DA="$(curl -sS --cacert "$CA" -X POST "$H/oauth/device_authorization")"
UC="$(printf '%s' "$DA"  | python3 -c "import sys,json;print(json.load(sys.stdin)['user_code'])")"
DC="$(printf '%s' "$DA"  | python3 -c "import sys,json;print(json.load(sys.stdin)['device_code'])")"
echo "   user_code=$UC  device_code=${DC:0:8}...(redacted)"

echo ">> [2] GET /device confirm page"
cfetch "$H/device?user_code=$UC" >/dev/null

echo ">> [3] POST /device (approve, same-origin)"
DEX_AUTH="$(cfetch -X POST "$H/device" \
  -H "Origin: $H" -H "Referer: $H/device?user_code=$UC" -H "Sec-Fetch-Site: same-origin" \
  --data-urlencode "user_code=$UC" -D - -o /dev/null \
  | awk 'tolower($1)=="location:"{print $2}' | tr -d '\r')"
[ -n "$DEX_AUTH" ] || { echo "ERROR: no redirect to Dex (CSRF block?)"; exit 1; }
echo "   -> Dex auth: ${DEX_AUTH:0:60}..."

echo ">> [4] follow to Dex login form"
cfetch -L "$DEX_AUTH" -o /tmp/dexform.html -D /tmp/dexH.txt >/dev/null
LOGIN_ACTION="$(python3 -c "import re,html; t=open('/tmp/dexform.html').read(); m=re.search(r'<form[^>]*action=\"([^\"]*/dex/auth/local/login[^\"]*)\"',t); print(html.unescape(m.group(1)) if m else '')")"
[ -n "$LOGIN_ACTION" ] || { echo "ERROR: Dex login form not found"; exit 1; }
echo "   login action: $LOGIN_ACTION"

echo ">> [5] POST Dex credentials for $EMAIL"
cfetch -L -X POST "$H$LOGIN_ACTION" \
  -H "Origin: $H" -H "Sec-Fetch-Site: same-origin" \
  --data-urlencode "login=$EMAIL" \
  --data-urlencode "password=$PASSWORD" \
  -o /tmp/postlogin.html -D /tmp/postloginH.txt >/dev/null
# Dex shows an approval/redirect; the gateway callback completes the device approval.
# Follow any further redirects through the cookie jar.
if grep -qiE 'grant|approve|/dex/approval' /tmp/postlogin.html; then
  APPROVE="$(python3 -c "import re,html; t=open('/tmp/postlogin.html').read(); m=re.search(r'<form[^>]*action=\"([^\"]*)\"',t); print(html.unescape(m.group(1)) if m else '')")"
  if [ -n "$APPROVE" ]; then
    echo "   approval form -> $APPROVE"
    case "$APPROVE" in http*) AURL="$APPROVE";; *) AURL="$H$APPROVE";; esac
    cfetch -L -X POST "$AURL" -H "Origin: $H" --data-urlencode "approval=approve" \
      -o /tmp/approve.html >/dev/null || true
  fi
fi

echo ">> [6] poll /oauth/token (device_code grant)"
TOKEN=""
for i in $(seq 1 12); do
  RESP="$(curl -sS --cacert "$CA" -X POST "$H/oauth/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    --data-urlencode "device_code=$DC" \
    --data-urlencode "client_id=claude-gateway")"
  AT="$(printf '%s' "$RESP" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); print(d.get('access_token',''))
except Exception: print('')" 2>/dev/null)"
  ERR="$(printf '%s' "$RESP" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); print(d.get('error',''))
except Exception: print('')" 2>/dev/null)"
  if [ -n "$AT" ]; then TOKEN="$AT"; break; fi
  echo "   poll $i: ${ERR:-pending}"
  sleep 3
done

[ -n "$TOKEN" ] || { echo "ERROR: no access token minted"; exit 1; }
printf '%s' "$TOKEN" > /tmp/gw_token.txt
echo ">> TOKEN MINTED: ${TOKEN:0:12}...(redacted, ${#TOKEN} chars) -> /tmp/gw_token.txt"
