# Static frontend: S3 (never public) + CloudFront in front of it, with
# /api/* forwarded straight through to the ALB from Milestone 2. Browser
# never talks to S3 or the ALB directly - only ever to the CloudFront
# domain, which is also why frontend/index.html can call a bare "/api/..."
# path with no hostname in it.
resource "aws_s3_bucket" "frontend" {
  bucket = "tkt-${var.owner_initials}-frontend"
  tags   = { Name = "tkt-${var.owner_initials}-frontend" }
}
# No public access of any kind - checklist item 22. CloudFront reaches
# this bucket through Origin Access Control (OAC), not a public bucket
# policy.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- CloudFront disabled temporarily (awaiting account verification from AWS Support) ---
# Uncomment once Case #1787243446000807 is resolved
#
# resource "aws_cloudfront_origin_access_control" "frontend" {
#   name                              = "tkt-${var.owner_initials}-oac"
#   origin_access_control_origin_type = "s3"
#   signing_behavior                  = "always"
#   signing_protocol                  = "sigv4"
# }
# resource "aws_cloudfront_distribution" "main" {
#   enabled             = true
#   default_root_object = "index.html"
#   comment              = "tkt-${var.owner_initials}"
#   origin {
#     domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
#     origin_id                = "s3-frontend"
#     origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
#   }
#   origin {
#     domain_name = aws_lb.main.dns_name
#     origin_id   = "alb-api"
#     custom_origin_config {
#       http_port              = 80
#       https_port              = 443
#       origin_protocol_policy = "http-only"
#       origin_ssl_protocols    = ["TLSv1.2"]
#     }
#   }
#   default_cache_behavior {
#     target_origin_id       = "s3-frontend"
#     viewer_protocol_policy = "redirect-to-https"
#     allowed_methods         = ["GET", "HEAD"]
#     cached_methods           = ["GET", "HEAD"]
#     cache_policy_id         = "658327ea-f89d-4fab-a63d-7e88639e58f6"
#   }
#   ordered_cache_behavior {
#     path_pattern            = "/api/*"
#     target_origin_id        = "alb-api"
#     viewer_protocol_policy  = "redirect-to-https"
#     allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
#     cached_methods            = ["GET", "HEAD"]
#     cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
#     origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
#   }
#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }
#   viewer_certificate {
#     cloudfront_default_certificate = true
#   }
#   tags = { Name = "tkt-${var.owner_initials}-cdn" }
# }
# resource "aws_s3_bucket_policy" "frontend" {
#   bucket = aws_s3_bucket.frontend.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Sid       = "AllowCloudFrontOAC"
#       Effect    = "Allow"
#       Principal = { Service = "cloudfront.amazonaws.com" }
#       Action    = "s3:GetObject"
#       Resource  = "${aws_s3_bucket.frontend.arn}/*"
#       Condition = {
#         StringEquals = {
#           "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
#         }
#       }
#     }]
#   })
# }
# output "cloudfront_url" {
#   value = "https://${aws_cloudfront_distribution.main.domain_name}"
# }

output "frontend_bucket" {
  value = aws_s3_bucket.frontend.bucket
}