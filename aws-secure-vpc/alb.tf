# -----------------------------------------------------------------------------
# alb.tf — Internet-facing ALB, Target Group (port 8000), Listener (port 80)
# -----------------------------------------------------------------------------
# Traffic path:
#   Client --:80--> ALB (public subnets) --:8000--> ASG instances (private)
# Health checks hit GET / on each instance; unhealthy instances are drained.
# -----------------------------------------------------------------------------

resource "aws_lb" "app" {
  name               = "${local.name_prefix}-alb"
  internal           = false # internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id # must span >= 2 AZs

  enable_deletion_protection = false

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# Target Group — instance type, HTTP:8000, health check on /
resource "aws_lb_target_group" "app" {
  name     = "${local.name_prefix}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

# Listener — accept HTTP:80 from clients and forward to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${local.name_prefix}-http-listener"
  }
}
