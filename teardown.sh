#!/usr/bin/env bash
# teardown.sh — remove everything this deployment created.
#   terraform destroy  (ECS, ALB, RDS, IAM, SGs, Route53, ACM, Secrets, logs)
# + ECR image cleanup   (both repos)
#
# Dry-run first:  bash teardown.sh --dry-run   (shows terraform plan -destroy)
# Real teardown:  bash teardown.sh --yes
set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"
TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/terraform" && pwd)"

MODE="${1:---dry-run}"

if [ "$MODE" = "--dry-run" ]; then
  echo ">> DRY RUN: terraform plan -destroy (no changes made)"
  terraform -chdir="$TF_DIR" plan -destroy
  echo
  echo ">> Would also delete ECR images in repos: claude-gateway, claude-gateway-dex"
  echo ">> Re-run with --yes to actually tear down."
  exit 0
fi

if [ "$MODE" != "--yes" ]; then
  echo "usage: teardown.sh [--dry-run|--yes]" >&2
  exit 2
fi

echo ">> Destroying Terraform-managed infrastructure"
terraform -chdir="$TF_DIR" destroy -auto-approve

echo ">> Deleting ECR repositories (images + repo)"
for repo in claude-gateway claude-gateway-dex; do
  if aws ecr describe-repositories --repository-names "$repo" --region "$REGION" >/dev/null 2>&1; then
    aws ecr delete-repository --repository-name "$repo" --region "$REGION" --force >/dev/null
    echo "   deleted ECR repo $repo"
  fi
done

echo ">> Teardown complete."
