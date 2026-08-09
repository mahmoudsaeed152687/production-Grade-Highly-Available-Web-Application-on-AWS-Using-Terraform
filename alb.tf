#Create ALB 
resource "aws_lb" "app" {
  name = "${var.project_name}-alb"

  load_balancer_type = "application"

  internal = false

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = values(aws_subnet.public)[*].id

  enable_deletion_protection = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alb"
    }
  )
}

#Target group 
resource "aws_lb_target_group" "app" {
  name = "${var.project_name}-tg"

  port     = 80
  protocol = "HTTP"

  vpc_id = aws_vpc.main.id

  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-tg"
    }
  )
}

#ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn

  port     = 80
  protocol = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-http-listener"
    }
  )
}
