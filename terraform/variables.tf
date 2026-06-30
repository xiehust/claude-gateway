variable "region" {
  type    = string
  default = "us-west-2"
}

# Set vpc_id and subnet_ids in a gitignored terraform.tfvars (see README).
variable "vpc_id" {
  type    = string
  default = "vpc-xxxxxxxxxxxxxxxxx"
}

variable "vpc_cidr" {
  type    = string
  default = "172.31.0.0/16"
}

# Two subnets in distinct AZs for the ALB + RDS subnet group (both require >=2 AZ).
# Default-VPC public subnets; the ALB is internal so it still gets private IPs,
# and Fargate tasks get public IPs to reach ECR/Bedrock.
variable "subnet_ids" {
  type    = list(string)
  default = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy"]
}

variable "private_zone_name" {
  type    = string
  default = "claude-gateway.internal"
}

variable "image_tag" {
  type    = string
  default = "2.1.196"
}

variable "db_username" {
  type    = string
  default = "gateway"
}

variable "db_name" {
  type    = string
  default = "gateway"
}

variable "log_retention_days" {
  type    = number
  default = 7
}
