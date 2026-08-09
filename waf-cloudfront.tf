
#WAF Web ACL
resource "aws_wafv2_web_acl" "alb" {
  name  = "${var.project_name}-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-alb-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alb-waf"
    }
  )
}

#Connect WAF with ALB 
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}

#CloudWatch metric for WAF
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name = "${var.project_name}-waf-blocked-requests"

  alarm_description = "Alarm when WAF blocks a high number of requests"

  namespace   = "AWS/WAFV2"
  metric_name = "BlockedRequests"

  statistic = "Sum"

  period = 300

  evaluation_periods = 1

  threshold = 10

  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    WebACL = aws_wafv2_web_acl.alb.name
    Region = var.aws_region
    Rule   = "ALL"
  }

  alarm_actions = [
    aws_sns_topic.alerts.arn
  ]

  tags = local.common_tags
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "app" {
  enabled = true

  comment = "${var.project_name} CloudFront distribution"

  origin {
    domain_name = aws_lb.app.dns_name
    origin_id   = "${var.project_name}-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"

      origin_ssl_protocols = [
        "TLSv1.2"
      ]
    }
  }

  # Dynamic application traffic
  default_cache_behavior {
    target_origin_id = "${var.project_name}-alb-origin"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "PUT",
      "POST",
      "PATCH",
      "DELETE"
    ]

    cached_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    compress = true

    forwarded_values {
      query_string = true

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Static assets caching
  ordered_cache_behavior {
    path_pattern = "/static/*"

    target_origin_id = "${var.project_name}-alb-origin"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    compress = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-cloudfront"
    }
  )
}


