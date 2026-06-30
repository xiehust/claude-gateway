#!/usr/bin/env bash
# laptop-setup.sh — one-time laptop setup so a PUBLIC machine can use the gateway
# through the SSM tunnel (laptop-connect.sh). Writes the CA, the hosts entry, and
# prints the env you need.
#
# Run once:  sudo bash laptop-setup.sh
set -euo pipefail

CA_DST="${CA_DST:-$HOME/claude-gateway-ca.pem}"
HOST="gw.claude-gateway.internal"

# The gateway CA (self-signed). Fingerprint (SHA-256):
#   3B:C4:CC:60:7A:3E:4E:CE:2B:2E:23:49:63:79:B0:CB:69:53:57:7E:64:74:C3:D6:39:62:24:33:B2:35:EB:A7
cat > "$CA_DST" <<'CAEOF'
-----BEGIN CERTIFICATE-----
MIIBvDCCAWKgAwIBAgIQXcvJrrPDbKWAiFH7JpTZJzAKBggqhkjOPQQDAjA+MRcw
FQYDVQQKEw5jbGF1ZGUtZ2F0ZXdheTEjMCEGA1UEAxMaY2xhdWRlLWdhdGV3YXkg
aW50ZXJuYWwgQ0EwHhcNMjYwNjMwMDYwMDEyWhcNMzYwNjI3MDYwMDEyWjA+MRcw
FQYDVQQKEw5jbGF1ZGUtZ2F0ZXdheTEjMCEGA1UEAxMaY2xhdWRlLWdhdGV3YXkg
aW50ZXJuYWwgQ0EwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARopOi57JVKMNAV
OKCYRB2OvCVf9f3TccjN93cJ2js8GnbY1FtLflxeFz/FhuNmOyl2m9s858nbyWlh
tM/kHnTMo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNV
HQ4EFgQUJA0ByikmqJPuj1JmJ3c2zo0u2N4wCgYIKoZIzj0EAwIDSAAwRQIhANx3
re0l6BziiwCxH1qYuQTKnaFDNB1Pt7Id5EawbopkAiA+aSsYjWS2AGCAz4CA44aj
3PfJgcoaGB8iVFop1yj7nQ==
-----END CERTIFICATE-----
CAEOF
echo ">> Wrote CA to $CA_DST"

# hosts entry so the cert SAN (gw.claude-gateway.internal) matches the tunnel.
if ! grep -q "$HOST" /etc/hosts 2>/dev/null; then
  echo "127.0.0.1 $HOST" >> /etc/hosts
  echo ">> Added '127.0.0.1 $HOST' to /etc/hosts"
else
  echo ">> /etc/hosts already has $HOST"
fi

cat <<EOF

>> Done. To use the gateway from this laptop:

   1) In terminal A, open the tunnel (keep it running):
        sudo bash laptop-connect.sh

   2) In terminal B, trust the CA and call the gateway:
        export NODE_EXTRA_CA_CERTS="$CA_DST"
        curl --cacert "$CA_DST" https://$HOST/healthz

   For browser sign-in, import $CA_DST into your OS/browser trust store.
EOF
