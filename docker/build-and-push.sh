#!/usr/bin/env bash
# build-and-push.sh — build the ARM64 gateway image and push it to ECR.
#
# Idempotent: creates the ECR repo only if absent; re-running just pushes the
# same tags again (safe). Account id is resolved dynamically.
set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"
REPO="claude-gateway"
VERSION="2.1.196"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPO}"

echo ">> Account=${ACCOUNT_ID} Region=${REGION} Image=${IMAGE}:${VERSION}"

# 1) Ensure the ECR repo exists (idempotent).
if ! aws ecr describe-repositories --repository-names "${REPO}" --region "${REGION}" >/dev/null 2>&1; then
  echo ">> Creating ECR repository ${REPO}"
  aws ecr create-repository \
    --repository-name "${REPO}" \
    --region "${REGION}" \
    --image-scanning-configuration scanOnPush=true \
    --tags Key=Project,Value=claude-gateway >/dev/null
else
  echo ">> ECR repository ${REPO} already exists"
fi

# 2) Build (host is aarch64 → native, no emulation).
echo ">> Building image"
docker build --platform linux/arm64 \
  -t "${REPO}:local" \
  -t "${IMAGE}:${VERSION}" \
  -t "${IMAGE}:latest" \
  "${SCRIPT_DIR}"

# 3) Login + push.
echo ">> Logging in to ECR"
aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

echo ">> Pushing ${IMAGE}:${VERSION} and :latest"
docker push "${IMAGE}:${VERSION}"
docker push "${IMAGE}:latest"

echo ">> Done. Pushed:"
echo "   ${IMAGE}:${VERSION}"
echo "   ${IMAGE}:latest"
