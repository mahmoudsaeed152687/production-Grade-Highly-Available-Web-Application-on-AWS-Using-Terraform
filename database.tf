# Private DB Subnets
resource "aws_subnet" "private_db" {
  for_each = {
    for index, az in var.availability_zones :
    az => {
      cidr = var.private_db_subnet_cidrs[index]
    }
  }

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value.cidr

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-db-${each.key}"
      Tier = "private-db"
    }
  )
}

#RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name = "${var.project_name}-db-subnet-group"

  subnet_ids = values(aws_subnet.private_db)[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-db-subnet-group"
    }
  )
}

#RDS PostgreSQL
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = "16"

  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  port = 5432

  multi_az = true

  db_subnet_group_name = aws_db_subnet_group.main.name

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  publicly_accessible = false

  backup_retention_period = 1

  backup_window = "03:00-04:00"

  maintenance_window = "sun:04:00-sun:05:00"

  auto_minor_version_upgrade = true

  deletion_protection = false

  skip_final_snapshot = true

  storage_encrypted = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-postgres"
    }
  )
}
