#!/usr/bin/env bash
# Build the gateway runtime image (base claude image + baked gateway.yaml) and
# push it to ECR as claude-gateway:<version>-gw.
set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"
REPO="claude-gateway"
VERSION="2.1.196"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
BASE="${REGISTRY}/${REPO}:${VERSION}"
IMAGE="${REGISTRY}/${REPO}:${VERSION}-gw"

echo ">> Building gateway image ${IMAGE} FROM ${BASE}"
docker build --platform linux/arm64 \
  --build-arg "BASE=${BASE}" \
  -f "${REPO_ROOT}/docker/Dockerfile.gateway" \
  -t "${IMAGE}" \
  "${REPO_ROOT}"

aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

docker push "${IMAGE}"
echo ">> Pushed ${IMAGE}"
