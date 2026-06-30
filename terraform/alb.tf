# Internal, IPv4-ONLY ALB. ip_address_type = "ipv4" is critical: dual-stack
# internal ALBs can return public-range AAAA records, which break the gateway
# /login private-network guard.
resource "aws_lb" "main" {
  name               = "claude-gateway-alb"
  internal           = true
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  tags = { Name = "claude-gateway-alb" }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.leaf.arn

  # Default action: 503 until services attach their rules (P3 Dex, P4 gateway).
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "no route"
      status_code  = "503"
    }
  }
}

# Target groups created here so P3/P4 only add listener rules + services.
resource "aws_lb_target_group" "dex" {
  name        = "claude-gateway-dex"
  port        = 5556
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/dex/.well-known/openid-configuration"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "claude-gateway-dex" }
}

resource "aws_lb_target_group" "gateway" {
  name        = "claude-gateway-gw"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "claude-gateway-gw" }
}

# Dex issuer path -> Dex target group (higher priority / more specific).
resource "aws_lb_listener_rule" "dex" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dex.arn
  }

  condition {
    path_pattern {
      values = ["/dex", "/dex/*"]
    }
  }
}

# Everything else (gateway root) -> gateway target group.
resource "aws_lb_listener_rule" "gateway" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
