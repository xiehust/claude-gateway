# Gateway service: the baked-config image + secrets/CA injected as env.
locals {
  gateway_image  = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com/claude-gateway:${var.image_tag}-gw"
  # CA PEM is non-secret (public cert) — inject as a plain env var so the
  # gateway trusts the self-signed ALB/Dex cert for OIDC discovery.
  oidc_ca_pem = tls_self_signed_cert.ca.cert_pem
}

resource "aws_ecs_task_definition" "gateway" {
  family                   = "claude-gateway"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "gateway"
      image     = local.gateway_image
      essential = true
      command   = ["claude", "gateway", "--config", "/etc/claude/gateway.yaml"]
      portMappings = [
        { containerPort = 8080, protocol = "tcp" }
      ]
      environment = [
        { name = "CLAUDE_CONFIG_DIR", value = "/tmp/.claude" },
        { name = "OIDC_CA_CERT_PEM", value = local.oidc_ca_pem },
        # Compliance posture: disable non-essential outbound traffic (set in P6
        # too; included here so the baseline task def already carries it).
        { name = "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", value = "1" },
      ]
      secrets = [
        { name = "OIDC_CLIENT_SECRET", valueFrom = aws_secretsmanager_secret.oidc_client_secret.arn },
        { name = "GATEWAY_JWT_SECRET", valueFrom = aws_secretsmanager_secret.jwt_secret.arn },
        { name = "GATEWAY_POSTGRES_URL", valueFrom = aws_secretsmanager_secret.postgres_url.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "gateway"
        }
      }
    }
  ])

  tags = { Name = "claude-gateway" }
}

resource "aws_ecs_service" "gateway" {
  name            = "gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.gateway.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Give the gateway time to run migrations + boot before health checks fail it.
  health_check_grace_period_seconds = 120

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gateway.arn
    container_name   = "gateway"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.https, aws_ecs_service.dex]

  tags = { Name = "claude-gateway" }
}
