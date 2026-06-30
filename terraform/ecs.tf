resource "aws_ecs_cluster" "main" {
  name = "claude-gateway"
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
  tags = { Name = "claude-gateway" }
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/claude-gateway"
  retention_in_days = var.log_retention_days
  tags              = { Name = "claude-gateway" }
}
