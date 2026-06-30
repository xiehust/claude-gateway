# Claude apps gateway — Step-by-step usage guide

This guide walks through everything you can do with the deployed gateway:
connecting a developer, verifying the deployment, inspecting audit logs,
operating the services, and tearing it all down.

- **Account / region:** `<AWS_ACCOUNT_ID>` / `us-west-2`
- **Gateway host:** `https://gw.claude-gateway.internal` (Route53 **private** zone — resolves only inside the VPC)
- **Test user:** `dev@example.com` / `gateway-dev-pw`
- **CA for TLS trust:** `claude-gateway/certs/ca.pem`

> ⚠️ The internal ALB resolves to **private RFC1918 IPs only**. Every command
> below must run from **inside the VPC** (e.g. the provisioning EC2 host
> `i-0785d8d0b8b950448`). From outside the VPC the hostname will not resolve.

---

## 0. Prerequisites (one-time, per shell)

```bash
cd /home/ubuntu/workspace/claude-gateway/claude-gateway

# AWS creds/region (the workshop EC2 host already has the admin role attached)
export AWS_REGION=us-west-2
aws sts get-caller-identity        # confirm you're in the right account

# Trust the gateway's self-signed CA for any TLS client (CLI, curl, node)
export NODE_EXTRA_CA_CERTS="$PWD/certs/ca.pem"
```

If `certs/ca.pem` is missing (fresh checkout), regenerate it from Terraform
state without changing infra:

```bash
terraform -chdir=terraform apply -auto-approve   # re-writes certs/ca.pem (no drift)
```

---

## 1. Confirm the deployment is healthy

```bash
CA=certs/ca.pem
H=https://gw.claude-gateway.internal

# Liveness + readiness (store reachable)
curl -sS --cacert $CA $H/healthz -w '\n%{http_code}\n'   # ok / 200
curl -sS --cacert $CA $H/readyz  -w '\n%{http_code}\n'   # ready / 200

# Gateway OAuth discovery (device + token endpoints)
curl -sS --cacert $CA $H/.well-known/oauth-authorization-server | jq

# ECS services should be 1/1 each
aws ecs describe-services --cluster claude-gateway --services gateway dex \
  --region us-west-2 \
  --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount}'
```

---

## 2. Verify the full loop end-to-end (sign-in → inference)

Two scripts do the whole RFC 8628 device flow and a Bedrock inference call:

```bash
# (a) Sign in via SSO (Dex), mint a gateway bearer token → /tmp/gw_token.txt
bash verify/e2e-signin.sh
#   ... >> TOKEN MINTED: eyJhbGci...(redacted)

# (b) Send a Messages API request through the gateway to Bedrock
bash verify/inference-check.sh
#   ... >> COMPLETION TEXT: gateway-bedrock-ok
#   ... >> INFERENCE_OK
```

`e2e-signin.sh` uses a **curl-scripted** redirect chain (device authorization →
Dex login with `dev@example.com`/`gateway-dev-pw` → token poll). Override the
target or creds with env vars:

```bash
GATEWAY_URL=https://gw.claude-gateway.internal \
DEV_EMAIL=dev@example.com DEV_PASSWORD=gateway-dev-pw \
bash verify/e2e-signin.sh
```

---

## 3. Make your own inference call (manual)

```bash
TOKEN=$(cat /tmp/gw_token.txt)        # from step 2(a)
CA=certs/ca.pem
H=https://gw.claude-gateway.internal

curl -sS --cacert $CA -X POST $H/v1/messages \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-opus-4-8",
    "max_tokens": 128,
    "messages": [{"role":"user","content":"Say hello from Bedrock."}]
  }' | jq
```

- A Bedrock-served response carries an `id` like `msg_bdrk_...`.
- List the models the gateway exposes:
  ```bash
  curl -sS --cacert $CA -H "Authorization: Bearer $TOKEN" $H/v1/models | jq '.data[].id'
  ```
- A model **not** in the allowlist is rejected server-side with HTTP 400
  (`model ... is not in the operator's model allowlist`).

---

## 4. Connect a real Claude Code CLI (developer machine inside the VPC)

1. Trust the CA:
   ```bash
   export NODE_EXTRA_CA_CERTS=/path/to/claude-gateway/certs/ca.pem
   ```
2. Install managed settings — copy `verify/managed-settings.json` to:
   - macOS: `/Library/Application Support/ClaudeCode/managed-settings.json`
   - Linux: `/etc/claude-code/managed-settings.json`

   ```json
   {
     "forceLoginMethod": "gateway",
     "forceLoginGatewayUrl": "https://gw.claude-gateway.internal"
   }
   ```
3. Sign in:
   ```bash
   claude /login
   ```
   On first connect the CLI shows the TLS leaf fingerprint — confirm it equals:
   ```
   28:D1:EE:2D:C2:D5:4A:D3:6F:F5:36:A5:8E:21:C4:E9:CF:BA:0C:0B:08:98:B3:E3:2D:32:40:06:6B:34:25:8A
   ```
   A browser opens the verification URL → sign in at Dex
   (`dev@example.com` / `gateway-dev-pw`) → approve. The CLI receives a bearer
   token and routes all inference through the gateway to Bedrock.

---

## 4b. Use the gateway from a public laptop (SSM tunnel)

The ALB is internal and `gw.claude-gateway.internal` only resolves inside the
VPC, so a public machine can't reach it directly. Instead of exposing anything
to the internet, tunnel through the in-VPC EC2 host with **SSM port forwarding**
(no inbound ports, no public IP). This was verified end-to-end (sign-in +
inference both work through the tunnel).

**Laptop prereqs:** AWS CLI v2 + the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html),
and AWS creds allowed to `ssm:StartSession` on the EC2 host.

**One-time setup** (writes the CA + a hosts entry):
```bash
sudo bash verify/laptop-setup.sh
# -> writes ~/claude-gateway-ca.pem and adds "127.0.0.1 gw.claude-gateway.internal"
#    to /etc/hosts. CA SHA-256:
#    3B:C4:CC:60:7A:3E:4E:CE:2B:2E:23:49:63:79:B0:CB:69:53:57:7E:64:74:C3:D6:39:62:24:33:B2:35:EB:A7
```

**Open the tunnel** (terminal A — keep it running):
```bash
sudo bash verify/laptop-connect.sh
# binds local 443 -> gw.claude-gateway.internal:443 via the EC2 host
```
> Local port **must be 443** — the gateway's `public_url` has no port, so the
> OIDC `redirect_uri` won't match if you remap to another port. Hence `sudo`
> (binding 443). The EC2 host resolves the private hostname for you.

**Use it** (terminal B):
```bash
export NODE_EXTRA_CA_CERTS=~/claude-gateway-ca.pem
curl --cacert ~/claude-gateway-ca.pem https://gw.claude-gateway.internal/healthz   # ok
```
Then run the steps in sections 2–4 unchanged (they all use the hostname).
For **browser sign-in**, import `~/claude-gateway-ca.pem` into your OS/browser
trust store so the `/device` page loads without a TLS warning.

> Alternatives if you can't bind 443 or want a more native experience: AWS
> Client VPN (laptop joins the VPC, the hostname resolves to the real private
> IP — nothing else changes) or an SSH `-L 443:gw.claude-gateway.internal:443`
> tunnel (needs port 22 + a public IP on the EC2 host).

---

## 5. Inspect the audit log

```bash
# Successful sign-ins (session.mint)
aws logs filter-log-events --region us-west-2 \
  --log-group-name /ecs/claude-gateway \
  --filter-pattern 'session.mint' --query 'events[].message' --output text

# Inference events (model, upstream, status, latency)
aws logs filter-log-events --region us-west-2 \
  --log-group-name /ecs/claude-gateway \
  --filter-pattern 'inference' --query 'events[].message' --output text

# Live tail of the whole gateway log
aws logs tail /ecs/claude-gateway --region us-west-2 --since 10m --follow
```

Expect `{"evt":"session.mint","result":"success","email":"dev@example.com",...}`
and `{"evt":"inference","model":"claude-opus-4-8","upstream":"bedrock","status":200,...}`.

---

## 6. Operate / change the deployment

```bash
# Re-apply infra (idempotent — should report "No changes")
terraform -chdir=terraform plan
terraform -chdir=terraform apply -auto-approve

# Rebuild + push images after editing config (then force a new deployment)
bash docker/build-and-push.sh            # base image (claude binary)
bash docker/build-gateway-image.sh       # gateway image (+ baked gateway.yaml)
bash dex/build-and-push.sh               # Dex image (+ baked config)

aws ecs update-service --cluster claude-gateway --service gateway \
  --force-new-deployment --region us-west-2
aws ecs update-service --cluster claude-gateway --service dex \
  --force-new-deployment --region us-west-2

# Scale the gateway (edit desired_count in terraform/gateway.tf, then apply),
# or temporarily:
aws ecs update-service --cluster claude-gateway --service gateway \
  --desired-count 2 --region us-west-2
```

**Where things live**
- `gateway.yaml` — gateway config (only `${ENV}` placeholders; no secrets)
- `dex/config.yaml` — Dex issuer, static client, static user
- `terraform/` — all AWS infra (ALB, RDS, IAM, SGs, ECS, ACM, Secrets, Route53)
- Secrets in Secrets Manager: `claude-gateway/{oidc-client-secret,jwt-secret,postgres-url}`

---

## 7. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `could not resolve host gw.claude-gateway.internal` | You're outside the VPC. Run from the in-VPC EC2 host. |
| `curl: SSL certificate problem: self signed` | Pass `--cacert certs/ca.pem` (or set `NODE_EXTRA_CA_CERTS`). |
| Sign-in `invalid_client` | Dex client secret mismatch — confirm the `dex` service redeployed after the secret was set (Dex doesn't expand env in config; the entrypoint substitutes it). |
| Sign-in `self signed certificate in certificate chain` | Gateway task missing `NODE_EXTRA_CA_CERTS` — it's set by `docker/gateway-entrypoint.sh`; rebuild/redeploy the gateway image. |
| `/readyz` 503 | Postgres unreachable — check RDS status and the task→RDS security group. |
| Gateway task crash-loops | `aws logs tail /ecs/claude-gateway` — the last stderr line names the fail-closed cause (config schema / Postgres / OIDC discovery / issuer mismatch). |

---

## 8. Tear down (removes everything)

```bash
# Preview — terraform plan -destroy, no changes made
bash teardown.sh --dry-run        # "Plan: 0 to add, 0 to change, 41 to destroy"

# Actually destroy all 41 resources + delete both ECR repos
bash teardown.sh --yes
```

This removes the ECS services/cluster, ALB, RDS, IAM roles, security groups,
Route53 zone, ACM cert, Secrets Manager entries, CloudWatch log group, and the
`claude-gateway` / `claude-gateway-dex` ECR repositories. Nothing is left
running.
