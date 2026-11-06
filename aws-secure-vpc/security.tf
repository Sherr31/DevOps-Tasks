# -----------------------------------------------------------------------------
# security.tf — Security Groups with tight cross-referencing
# -----------------------------------------------------------------------------
# Dependency order (avoids circular SG references):
#   1. ALB SG   — standalone (ingress from internet)
#   2. Bastion SG — standalone (ingress SSH from admin CIDR)
#   3. App SG   — references ALB SG (port 8000) and Bastion SG (SSH)
#
# App SG never needs to be referenced by ALB or Bastion SGs, so there is no
# cycle. Prefer aws_security_group_rule resources when both SGs must reference
# each other; here a single direction is enough.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ALB Security Group
# Internet clients hit the ALB on HTTP/80. ALB then talks to app instances.
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow inbound HTTP from the internet to the ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound (ALB to targets on app port)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# -----------------------------------------------------------------------------
# Bastion Security Group
# Jump host in a public subnet. Restrict bastion_ssh_cidr to your IP/32 in prod.
# -----------------------------------------------------------------------------
resource "aws_security_group" "bastion" {
  name        = "${local.name_prefix}-bastion-sg"
  description = "Allow SSH to bastion from trusted CIDR"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.bastion_ssh_cidr]
  }

  egress {
    description = "All outbound (bastion to private instances via SSH)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-bastion-sg"
  }
}

# -----------------------------------------------------------------------------
# App / Private Instances Security Group
# - App traffic ONLY from ALB SG (not from the open internet)
# - SSH ONLY from Bastion SG (no public SSH to private instances)
# -----------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "App instances: HTTP from ALB, SSH from bastion only"
  vpc_id      = aws_vpc.main.id

  # Port 8000 from ALB SG only — this is how the load balancer reaches the app.
  ingress {
    description     = "App HTTP from ALB security group"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH from Bastion SG only — jump-host pattern.
  ingress {
    description     = "SSH from bastion security group"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "All outbound (via NAT for package installs, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-app-sg"
  }
}
