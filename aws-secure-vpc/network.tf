# -----------------------------------------------------------------------------
# network.tf — VPC, subnets, IGW, NAT Gateway, route tables
# -----------------------------------------------------------------------------
# Layout (matches Day-7 production pattern):
#
#   Internet
#      |
#     IGW  ---- public route table ---- public subnet AZ-a (NAT GW lives here)
#                                  \--- public subnet AZ-b
#      |
#   NAT GW ---- private route table --- private subnet AZ-a (ASG instances)
#                                  \--- private subnet AZ-b (ASG instances)
# -----------------------------------------------------------------------------

# Dynamic AZ lookup — never hard-code us-east-1a/1b; regions differ.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use the first two available AZs in the region.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  name_prefix = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Public subnets (ALB + Bastion + NAT Gateway)
# map_public_ip_on_launch = true so instances (bastion) get a public IP.
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

# -----------------------------------------------------------------------------
# Private subnets (ASG / app instances — no direct internet inbound)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-private-${local.azs[count.index]}"
    Tier = "private"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway — required for public subnet internet access & ALB traffic
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# -----------------------------------------------------------------------------
# Elastic IP + NAT Gateway
# NAT sits in public[0] so private instances can reach the internet outbound
# (apt, yum, AMI updates) without being publicly reachable inbound.
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }

  # Ensure IGW exists before allocating EIP used by NAT in a public subnet.
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${local.name_prefix}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Public route table: 0.0.0.0/0 -> IGW, associated with BOTH public subnets
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Private route table: 0.0.0.0/0 -> NAT Gateway, associated with BOTH private subnets
# -----------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
