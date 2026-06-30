#!/bin/sh
# Substitute the client secret into the config at start. Dex v2.41.1 does not
# expand env vars in config, and turning that on would corrupt the bcrypt
# password hash ($2b$...). The secret is alphanumeric (random_password
# special=false), so a plain sed replace is safe.
set -e
: "${DEX_CLIENT_SECRET:?DEX_CLIENT_SECRET must be set}"
sed "s|DEX_CLIENT_SECRET_PLACEHOLDER|${DEX_CLIENT_SECRET}|" \
  /etc/dex/config.yaml > /tmp/dex-config.yaml
exec /usr/local/bin/dex serve /tmp/dex-config.yaml
