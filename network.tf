locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

#aws_vpc
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

# Creating internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}

# Creating public subnets
resource "aws_subnet" "public" {
  for_each = {
    for index, az in var.availability_zones :
    az => {
      cidr = var.public_subnet_cidrs[index]
    }
  }

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.key
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-public-${each.key}"
      Tier = "public"
    }
  )
}

# Creating app private subnets 
resource "aws_subnet" "private_app" {
  for_each = {
    for index, az in var.availability_zones :
    az => {
      cidr = var.private_app_subnet_cidrs[index]
    }
  }

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = each.value.cidr

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-app-${each.key}"
      Tier = "private-app"
    }
  )
}


# Public RT
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-public-rt"
    }
  )
}

#Associate public subnets with public RT
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

#Elastic ip 
resource "aws_eip" "nat" {
  for_each = aws_subnet.public

  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-nat-eip-${each.key}"
    }
  )
}

#Nat
resource "aws_nat_gateway" "main" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  depends_on = [
    aws_internet_gateway.main
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-nat-${each.key}"
    }
  )
}

#Private App Route Table
resource "aws_route_table" "private_app" {
  for_each = aws_subnet.private_app

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-app-rt-${each.key}"
    }
  )
}

#Association private app route tables
resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

# Private DB Route Table
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-db-rt"
    }
  )
}

# DB RT association
resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db.id
}
