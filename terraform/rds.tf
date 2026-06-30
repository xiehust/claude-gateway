resource "random_password" "db" {
  length  = 32
  special = false # avoid URL-encoding headaches in the postgres_url
}

resource "aws_db_subnet_group" "main" {
  name       = "claude-gateway"
  subnet_ids = var.subnet_ids
  tags       = { Name = "claude-gateway" }
}

resource "aws_db_instance" "main" {
  identifier     = "claude-gateway"
  engine         = "postgres"
  engine_version = "16.14"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az            = false
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  tags = { Name = "claude-gateway" }
}

locals {
  postgres_url = "postgres://${var.db_username}:${random_password.db.result}@${aws_db_instance.main.address}:5432/${var.db_name}?sslmode=require"
}
