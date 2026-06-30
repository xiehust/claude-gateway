#!/bin/sh
# Write the injected CA PEM to a file and point NODE_EXTRA_CA_CERTS at it so
# ALL of the gateway's TLS clients trust the self-signed ALB/Dex cert — not just
# the OIDC discovery client (oidc.ca_cert_pem covers discovery but the
# back-channel token-exchange client needs the process-wide trust store).
set -e
if [ -n "${OIDC_CA_CERT_PEM:-}" ]; then
  printf '%s\n' "$OIDC_CA_CERT_PEM" > /tmp/oidc-ca.pem
  export NODE_EXTRA_CA_CERTS=/tmp/oidc-ca.pem
fi
exec "$@"
