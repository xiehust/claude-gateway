#!/usr/bin/env bash
# Build the Dex wrapper image (arm64) and push to ECR repo claude-gateway-dex.
set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"
REPO="claude-gateway-dex"
TAG="v2.41.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPO}"

echo ">> Image=${IMAGE}:${TAG}"

if ! aws ecr describe-repositories --repository-names "${REPO}" --region "${REGION}" >/dev/null 2>&1; then
  echo ">> Creating ECR repository ${REPO}"
  aws ecr create-repository --repository-name "${REPO}" --region "${REGION}" \
    --tags Key=Project,Value=claude-gateway >/dev/null
fi

docker build --platform linux/arm64 -t "${REPO}:local" -t "${IMAGE}:${TAG}" "${SCRIPT_DIR}"

aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

docker push "${IMAGE}:${TAG}"
echo ">> Pushed ${IMAGE}:${TAG}"
