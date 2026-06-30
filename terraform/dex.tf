# Dex OIDC IdP service. Image is the wrapper built in claude-gateway/dex/.
locals {
  dex_image = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com/claude-gateway-dex:v2.41.1"
}

resource "aws_ecs_task_definition" "dex" {
  family                   = "claude-gateway-dex"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name      = "dex"
      image     = local.dex_image
      essential = true
      portMappings = [
        { containerPort = 5556, protocol = "tcp" }
      ]
      secrets = [
        {
          name      = "DEX_CLIENT_SECRET"
          valueFrom = aws_secretsmanager_secret.oidc_client_secret.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "dex"
        }
      }
    }
  ])

  tags = { Name = "claude-gateway-dex" }
}

resource "aws_ecs_service" "dex" {
  name            = "dex"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.dex.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true # default-VPC public subnets: needed to pull from ECR
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dex.arn
    container_name   = "dex"
    container_port   = 5556
  }

  depends_on = [aws_lb_listener.https]

  tags = { Name = "claude-gateway-dex" }
}
