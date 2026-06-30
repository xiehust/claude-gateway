data "aws_vpc" "main" {
  id = var.vpc_id
}

# ---- Security groups ----------------------------------------------------

# ALB: ingress 443 from the VPC CIDR only (internal). Egress to tasks.
resource "aws_security_group" "alb" {
  name        = "claude-gateway-alb"
  description = "Internal ALB for claude-gateway: 443 from VPC CIDR"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "claude-gateway-alb" }
}

# Tasks: ingress on gateway (8080) + Dex (5556) from the ALB SG only.
resource "aws_security_group" "tasks" {
  name        = "claude-gateway-tasks"
  description = "ECS tasks: 8080/5556 from ALB SG only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Gateway from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Dex from ALB"
    from_port       = 5556
    to_port         = 5556
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All egress (ECR, Bedrock, IdP)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "claude-gateway-tasks" }
}

# RDS: ingress 5432 from the task SG only.
resource "aws_security_group" "rds" {
  name        = "claude-gateway-rds"
  description = "RDS Postgres: 5432 from task SG only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.tasks.id]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "claude-gateway-rds" }
}

# ---- Route53 private zone + stable ALB alias ----------------------------

resource "aws_route53_zone" "private" {
  name = var.private_zone_name
  vpc {
    vpc_id = var.vpc_id
  }
  tags = { Name = "claude-gateway-private" }
}

resource "aws_route53_record" "gw" {
  zone_id = aws_route53_zone.private.zone_id
  name    = local.alb_host
  type    = "A"
  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = false
  }
}
