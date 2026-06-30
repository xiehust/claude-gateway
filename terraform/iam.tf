data "aws_iam_policy_document" "ecs_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---- Task role: least-privilege Bedrock invoke -------------------------
data "aws_iam_policy_document" "bedrock" {
  statement {
    sid    = "BedrockInvoke"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      "arn:aws:bedrock:${var.region}::foundation-model/anthropic.*",
      "arn:aws:bedrock:us-*::foundation-model/anthropic.*",
      "arn:aws:bedrock:${var.region}:${local.account_id}:inference-profile/us.anthropic.*",
    ]
  }
}

resource "aws_iam_role" "task" {
  name               = "claude-gateway-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Name = "claude-gateway-task" }
}

resource "aws_iam_role_policy" "task_bedrock" {
  name   = "bedrock-invoke"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.bedrock.json
}

# ---- Execution role: ECR pull + logs + secrets read --------------------
resource "aws_iam_role" "exec" {
  name               = "claude-gateway-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  tags               = { Name = "claude-gateway-exec" }
}

resource "aws_iam_role_policy_attachment" "exec_managed" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "exec_secrets" {
  statement {
    sid    = "ReadGatewaySecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      aws_secretsmanager_secret.oidc_client_secret.arn,
      aws_secretsmanager_secret.jwt_secret.arn,
      aws_secretsmanager_secret.postgres_url.arn,
    ]
  }
}

resource "aws_iam_role_policy" "exec_secrets" {
  name   = "read-secrets"
  role   = aws_iam_role.exec.id
  policy = data.aws_iam_policy_document.exec_secrets.json
}
