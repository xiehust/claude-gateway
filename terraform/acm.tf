# Self-signed CA + leaf for the internal ALB hostname, generated deterministically
# by the tls provider (no openssl shell-out). The leaf SAN is the stable
# Route53 hostname local.alb_host, known upfront -> no two-pass apply needed.
# The CA PEM is written to certs/ca.pem for oidc.ca_cert_pem and CLI trust.

resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "claude-gateway internal CA"
    organization = "claude-gateway"
  }

  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}

resource "tls_private_key" "leaf" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "leaf" {
  private_key_pem = tls_private_key.leaf.private_key_pem

  subject {
    common_name  = local.alb_host
    organization = "claude-gateway"
  }

  dns_names = [local.alb_host]
}

resource "tls_locally_signed_cert" "leaf" {
  cert_request_pem   = tls_cert_request.leaf.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 26280 # 3 years

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "leaf" {
  private_key       = tls_private_key.leaf.private_key_pem
  certificate_body  = tls_locally_signed_cert.leaf.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem

  tags = { Name = "claude-gateway-leaf" }

  lifecycle {
    create_before_destroy = true
  }
}

# Persist the CA (and leaf fingerprint material) to the certs/ dir (gitignored).
resource "local_sensitive_file" "ca_pem" {
  content         = tls_self_signed_cert.ca.cert_pem
  filename        = "${path.module}/../certs/ca.pem"
  file_permission = "0644"
}

resource "local_sensitive_file" "leaf_pem" {
  content         = tls_locally_signed_cert.leaf.cert_pem
  filename        = "${path.module}/../certs/leaf.pem"
  file_permission = "0644"
}
