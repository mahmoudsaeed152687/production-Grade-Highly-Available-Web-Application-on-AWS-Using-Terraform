locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
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

#Public NACL
resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-public-nacl"
      Tier = "public"
    }
  )
}

#Private App NACL
resource "aws_network_acl" "private_app" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-app-nacl"
      Tier = "private-app"
    }
  )
}

#Private DB NACL
resource "aws_network_acl" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-private-db-nacl"
      Tier = "private-db"
    }
  )
}

#Public NACL Rules
#Inbound
resource "aws_network_acl_rule" "public_ingress_http" {
  network_acl_id = aws_network_acl.public.id

  rule_number = 100
  egress      = false
  protocol    = "tcp"
  rule_action = "allow"

  cidr_block = "0.0.0.0/0"

  from_port = 80
  to_port   = 80
}

resource "aws_network_acl_rule" "public_ingress_https" {
  network_acl_id = aws_network_acl.public.id

  rule_number = 110
  egress      = false
  protocol    = "tcp"
  rule_action = "allow"

  cidr_block = "0.0.0.0/0"

  from_port = 443
  to_port   = 443
}

#Outbound
resource "aws_network_acl_rule" "public_egress" {
  network_acl_id = aws_network_acl.public.id

  rule_number = 100
  egress      = true
  protocol    = "-1"
  rule_action = "allow"

  cidr_block = "0.0.0.0/0"
}

#Private App NACL
#Inbound
resource "aws_network_acl_rule" "private_app_ingress" {
  network_acl_id = aws_network_acl.private_app.id

  rule_number = 100
  egress      = false
  protocol    = "-1"
  rule_action = "allow"

  cidr_block = "10.0.0.0/16"
}

#Outbound
resource "aws_network_acl_rule" "private_app_egress" {
  network_acl_id = aws_network_acl.private_app.id

  rule_number = 100
  egress      = true
  protocol    = "-1"
  rule_action = "allow"

  cidr_block = "0.0.0.0/0"
}

#Private DB NACL
resource "aws_network_acl_rule" "private_db_ingress" {
  network_acl_id = aws_network_acl.private_db.id

  rule_number = 100
  egress      = false
  protocol    = "-1"
  rule_action = "allow"

  cidr_block = var.vpc_cidr
}

resource "aws_network_acl_rule" "private_db_egress" {
  network_acl_id = aws_network_acl.private_db.id

  rule_number = 100
  egress      = true
  protocol    = "-1"
  rule_action = "allow"

  cidr_block = var.vpc_cidr
}

#Association public subnets with NACLs
resource "aws_network_acl_association" "public" {
  for_each = aws_subnet.public

  network_acl_id = aws_network_acl.public.id
  subnet_id      = each.value.id
}

#Association private app subnets with NACLs
resource "aws_network_acl_association" "private_app" {
  for_each = aws_subnet.private_app

  network_acl_id = aws_network_acl.private_app.id
  subnet_id      = each.value.id
}

#Association private DB subnets with NACLs
resource "aws_network_acl_association" "private_db" {
  for_each = aws_subnet.private_db

  network_acl_id = aws_network_acl.private_db.id
  subnet_id      = each.value.id
}



