#!/usr/bin/env bash
# laptop-connect.sh — open an SSM port-forward tunnel from a PUBLIC laptop to the
# internal Claude gateway ALB, so you can reach https://gw.claude-gateway.internal
# without exposing anything to the internet.
#
# Prereqs on the laptop:
#   - AWS CLI v2 + the Session Manager plugin installed
#       https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
#   - AWS creds for account that can ssm:StartSession on the EC2 host
#   - The gateway CA trusted (see laptop-setup.sh) and a hosts entry:
#       127.0.0.1 gw.claude-gateway.internal
#   - Local port 443 free (script uses sudo-free 8443->local, but the gateway
#     public_url has no port, so we MUST bind local 443; run with sudo or grant
#     CAP_NET_BIND, OR use the socat trick noted below).
#
# Usage:  sudo bash laptop-connect.sh
set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"
TARGET_INSTANCE="${TARGET_INSTANCE:-i-0785d8d0b8b950448}"
REMOTE_HOST="${REMOTE_HOST:-gw.claude-gateway.internal}"
REMOTE_PORT="${REMOTE_PORT:-443}"
LOCAL_PORT="${LOCAL_PORT:-443}"

echo ">> SSM port-forward: localhost:${LOCAL_PORT} -> ${REMOTE_HOST}:${REMOTE_PORT} (via ${TARGET_INSTANCE})"
echo ">> Keep this terminal open. Ctrl-C to disconnect."
exec aws ssm start-session \
  --region "$REGION" \
  --target "$TARGET_INSTANCE" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=${REMOTE_HOST},portNumber=${REMOTE_PORT},localPortNumber=${LOCAL_PORT}"
