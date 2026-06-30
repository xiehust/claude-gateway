#!/usr/bin/env bash
# inference-check.sh — call the gateway's Anthropic Messages API with the gateway
# bearer token and confirm a real Claude completion comes back from Bedrock.
# Proves: bearer auth + model translation (claude-opus-4-8 ->
# us.anthropic.claude-opus-4-8) + Bedrock forwarding.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CA="${ROOT}/certs/ca.pem"
H="${GATEWAY_URL:-https://gw.claude-gateway.internal}"
MODEL="${MODEL:-claude-opus-4-8}"
TOKEN="$(cat "${TOKEN_FILE:-/tmp/gw_token.txt}")"

echo ">> POST $H/v1/messages  model=$MODEL"
RESP="$(curl -sS --cacert "$CA" -X POST "$H/v1/messages" \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "{
    \"model\": \"$MODEL\",
    \"max_tokens\": 64,
    \"messages\": [{\"role\":\"user\",\"content\":\"Reply with exactly: gateway-bedrock-ok\"}]
  }")"

echo ">> raw response (first 600 chars):"
printf '%s\n' "$RESP" | head -c 600; echo

TEXT="$(printf '%s' "$RESP" | python3 -c "import sys,json
d=json.load(sys.stdin)
parts=[b.get('text','') for b in d.get('content',[]) if b.get('type')=='text']
print(''.join(parts).strip())" 2>/dev/null || true)"

if [ -z "$TEXT" ]; then
  echo "ERROR: no assistant text in response"
  exit 1
fi
echo ">> COMPLETION TEXT: $TEXT"
echo ">> INFERENCE_OK"
