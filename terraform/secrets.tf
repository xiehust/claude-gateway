# Use a 7-day recovery window default; force-overwrite friendly for a workshop.
resource "random_password" "jwt" {
  length  = 48
  special = false
}

resource "random_password" "oidc_client_secret" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "claude-gateway/jwt-secret"
  recovery_window_in_days = 0
  tags                    = { Name = "claude-gateway-jwt" }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt.result
}

resource "aws_secretsmanager_secret" "postgres_url" {
  name                    = "claude-gateway/postgres-url"
  recovery_window_in_days = 0
  tags                    = { Name = "claude-gateway-pg" }
}

resource "aws_secretsmanager_secret_version" "postgres_url" {
  secret_id     = aws_secretsmanager_secret.postgres_url.id
  secret_string = local.postgres_url
}

# OIDC client secret: shared between Dex (staticClient) and the gateway.
# Generated here so both P3 (Dex) and P4 (gateway) read the same value.
resource "aws_secretsmanager_secret" "oidc_client_secret" {
  name                    = "claude-gateway/oidc-client-secret"
  recovery_window_in_days = 0
  tags                    = { Name = "claude-gateway-oidc" }
}

resource "aws_secretsmanager_secret_version" "oidc_client_secret" {
  secret_id     = aws_secretsmanager_secret.oidc_client_secret.id
  secret_string = random_password.oidc_client_secret.result
}
