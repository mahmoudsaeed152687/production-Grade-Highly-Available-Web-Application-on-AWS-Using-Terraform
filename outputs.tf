output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = values(aws_subnet.public)[*].id
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs"
  value       = values(aws_subnet.private_app)[*].id
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs"
  value       = values(aws_subnet.private_db)[*].id
}


output "ec2_instance_profile_name" {
  description = "IAM instance profile used by EC2 instances"
  value       = aws_iam_instance_profile.ec2.name
}

output "ec2_ssm_role_arn" {
  description = "IAM role ARN for EC2 SSM access"
  value       = aws_iam_role.ec2_ssm.arn
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.app.id
}


output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.app.dns_name
}

output "target_group_arn" {
  description = "Target Group ARN"
  value       = aws_lb_target_group.app.arn
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.main.port
}

output "sns_topic_arn" {
  description = "SNS alerts topic ARN"
  value       = aws_sns_topic.alerts.arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.alb.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.app.domain_name
}

