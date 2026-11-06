# -----------------------------------------------------------------------------
# compute.tf — Launch Template, user_data app, ASG, Bastion host
# -----------------------------------------------------------------------------
# Flow:
#   Launch Template (Ubuntu 22.04 + user_data Python HTTP on :8000)
#        |
#   Auto Scaling Group (private subnets) ---- registered with ALB Target Group
#
#   Bastion EC2 (public subnet) — SSH jump host into private instances
# -----------------------------------------------------------------------------

# Latest Ubuntu 22.04 LTS AMI from Canonical (owner 099720109477).
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# -----------------------------------------------------------------------------
# user_data — writes index.html and starts python3 HTTP server on port 8000
# Terraform base64-encodes this for the Launch Template.
# -----------------------------------------------------------------------------
locals {
  # $${...} escapes Terraform interpolation so bash expands HOSTNAME_FQDN at boot.
  app_user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    HOSTNAME_FQDN="$(hostname -f)"

    # Identity page — refresh the ALB URL to see different ASG instance hostnames.
    cat > /home/ubuntu/index.html <<HTML
    <!DOCTYPE html>
    <html>
    <head><title>Secure VPC App</title></head>
    <body>
      <h1>Hello from EC2 instance: $${HOSTNAME_FQDN}</h1>
    </body>
    </html>
    HTML

    cd /home/ubuntu
    # Serve on 8000 in the background — ALB TG + health check use this port.
    nohup python3 -m http.server ${var.app_port} >/home/ubuntu/http-server.log 2>&1 &
  EOF
}

# -----------------------------------------------------------------------------
# Launch Template — blueprint for ASG-managed private instances
# -----------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${local.name_prefix}-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  # App SG only — no public IP; outbound via NAT.
  vpc_security_group_ids = [aws_security_group.app.id]

  user_data = base64encode(local.app_user_data)

  # Ensure instances launched by the ASG get the Name tag pattern below.
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-app"
      Role = "app"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${local.name_prefix}-app-volume"
    }
  }

  tags = {
    Name = "${local.name_prefix}-app-lt"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling Group — spans BOTH private subnets (multi-AZ)
# Desired 2 / Min 1 / Max 3; attached to ALB Target Group for traffic + health.
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group" "app" {
  name                      = "${local.name_prefix}-app-asg"
  vpc_zone_identifier       = aws_subnet.private[*].id
  desired_capacity          = var.asg_desired_capacity
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  health_check_type         = "ELB"
  health_check_grace_period = 120

  # Register instances with the ALB target group (defined in alb.tf).
  target_group_arns = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-app-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "app"
    propagate_at_launch = true
  }

  # Wait until instances are InService / healthy before Terraform finishes apply.
  wait_for_capacity_timeout = "10m"
}

# -----------------------------------------------------------------------------
# Bastion / Jump Host — public subnet, public IP, Bastion SG + SSH key
# SSH: ssh -i <key.pem> ubuntu@<bastion_public_ip>
# Then:  ssh ubuntu@<private_instance_ip>
# -----------------------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${local.name_prefix}-bastion"
    Role = "bastion"
  }
}
