terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project = "claude-gateway"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Stable internal hostname served by the ALB (Route53 private zone alias).
  # Used as the TLS leaf SAN, the gateway public_url host, and the Dex issuer host.
  # Fixed string -> no dependency on the ALB's auto-generated DNS name.
  alb_host    = "gw.${var.private_zone_name}"
  public_url  = "https://${local.alb_host}"
  dex_issuer  = "https://${local.alb_host}/dex"
  ecr_image   = "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com/claude-gateway:${var.image_tag}"
}
