#EC2 IAM role
resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ec2-ssm-role"
    }
  )
}

#Attach SSM Policy
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-instance-profile"

  role = aws_iam_role.ec2_ssm.name

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ec2-instance-profile"
    }
  )
}

#Data source for AMI
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

#Launch template
resource "aws_launch_template" "app" {
  name = "${var.project_name}-app-lt"

  image_id = data.aws_ssm_parameter.amazon_linux_2023.value

  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash

    dnf update -y

    dnf install -y nginx

    systemctl enable nginx
    systemctl start nginx

    cat > /usr/share/nginx/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
    <head>
      <title>Scalable Web App</title>
    </head>
    <body>
      <h1>Hello from AWS!</h1>
      <p>Instance: $(hostname) </p>
    </body>
    </html>
    HTML
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-app-instance"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-app-launch-template"
    }
  )
}

#Auto scaling group 
resource "aws_autoscaling_group" "app" {
  name = "${var.project_name}-asg"

  min_size         = 2
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = values(aws_subnet.private_app)[*].id

  health_check_type = "ELB"

  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.app.arn
  ]

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}

#Target Tracking
resource "aws_autoscaling_policy" "target_tracking" {
  name = "${var.project_name}-cpu-target-tracking"

  autoscaling_group_name = aws_autoscaling_group.app.name

  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}
