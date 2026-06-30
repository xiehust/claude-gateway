output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_host" {
  description = "Stable internal hostname clients connect to (Route53 private)"
  value       = local.alb_host
}

output "public_url" {
  value = local.public_url
}

output "dex_issuer" {
  value = local.dex_issuer
}

output "ecr_image" {
  value = local.ecr_image
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "log_group" {
  value = aws_cloudwatch_log_group.main.name
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "exec_role_arn" {
  value = aws_iam_role.exec.arn
}

output "task_sg_id" {
  value = aws_security_group.tasks.id
}

output "subnet_ids" {
  value = var.subnet_ids
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.leaf.arn
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}

output "dex_target_group_arn" {
  value = aws_lb_target_group.dex.arn
}

output "gateway_target_group_arn" {
  value = aws_lb_target_group.gateway.arn
}

output "oidc_client_secret_arn" {
  value = aws_secretsmanager_secret.oidc_client_secret.arn
}

output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.jwt_secret.arn
}

output "postgres_url_arn" {
  value = aws_secretsmanager_secret.postgres_url.arn
}

output "rds_address" {
  value = aws_db_instance.main.address
}
