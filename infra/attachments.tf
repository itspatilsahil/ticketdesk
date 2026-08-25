# S3 bucket for uploads + thumbnails, an execution role + function for
# the thumbnail Lambda, and the S3 event notification wiring them together.
resource "aws_s3_bucket" "attachments" {
  bucket = "tkt-${var.owner_initials}-attachments"
  tags   = { Name = "tkt-${var.owner_initials}-attachments" }
}
resource "aws_s3_bucket_public_access_block" "attachments" {
  bucket                  = aws_s3_bucket.attachments.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
# The browser uploads directly to S3 using a presigned URL - that PUT
# request comes from the CloudFront domain's origin, so S3 needs a CORS
# rule allowing it. Scoped to https only; tighten allowed_origins to your
# exact CloudFront domain once Milestone 4's distribution exists if you
# want to remove the wildcard.
resource "aws_s3_bucket_cors_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id
  cors_rule {
    allowed_methods = ["PUT", "GET"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds  = 3000
  }
}
# --- Task role: the application itself now calls AWS directly (to sign
# URLs), for the first time in this project. Scoped to exactly this
# bucket, exactly these two actions - never "*" on "*". ---------------
resource "aws_iam_role_policy" "ecs_task_attachments" {
  name = "tkt-${var.owner_initials}-ecs-task-attachments"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = ["${aws_s3_bucket.attachments.arn}/*"]
    }]
  })
}

# --- Lambda parts disabled for now (build.sh didn't create zip file) ---
# Uncomment when lambda-thumbnail/build/thumbnail.zip is ready
#
# resource "aws_iam_role" "lambda_thumbnail" {
#   name = "tkt-${var.owner_initials}-lambda-thumbnail-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect    = "Allow"
#       Principal = { Service = "lambda.amazonaws.com" }
#       Action    = "sts:AssumeRole"
#     }]
#   })
# }
# resource "aws_iam_role_policy" "lambda_thumbnail" {
#   name = "tkt-${var.owner_initials}-lambda-thumbnail-policy"
#   role = aws_iam_role.lambda_thumbnail.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = ["s3:GetObject"]
#         Resource = ["${aws_s3_bucket.attachments.arn}/uploads/*"]
#       },
#       {
#         Effect   = "Allow"
#         Action   = ["s3:PutObject"]
#         Resource = ["${aws_s3_bucket.attachments.arn}/thumbnails/*"]
#       },
#       {
#         Effect   = "Allow"
#         Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
#         Resource = ["arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/tkt-${var.owner_initials}-thumbnail*"]
#       }
#     ]
#   })
# }
# resource "aws_cloudwatch_log_group" "lambda_thumbnail" {
#   name              = "/aws/lambda/tkt-${var.owner_initials}-thumbnail"
#   retention_in_days = var.log_retention_days
# }
# resource "aws_lambda_function" "thumbnail" {
#   function_name = "tkt-${var.owner_initials}-thumbnail"
#   role          = aws_iam_role.lambda_thumbnail.arn
#   handler       = "handler.handler"
#   runtime       = "python3.12"
#   filename = "C:/Users/patil/Downloads/ticketdesk-complete/ticketdesk/lambda-thumbnail/build/thumbnail.zip"
#   source_code_hash = filebase64sha256("${path.module}/../lambda-thumbnail/build/thumbnail.zip")
#   timeout      = 15
#   memory_size  = 256
#   depends_on = [aws_cloudwatch_log_group.lambda_thumbnail]
#   tags = { Name = "tkt-${var.owner_initials}-thumbnail" }
# }
# resource "aws_lambda_permission" "allow_s3" {
#   statement_id  = "AllowS3Invoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.thumbnail.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.attachments.arn
# }
# resource "aws_s3_bucket_notification" "attachments" {
#   bucket = aws_s3_bucket.attachments.id
#   lambda_function {
#     lambda_function_arn = aws_lambda_function.thumbnail.arn
#     events               = ["s3:ObjectCreated:*"]
#     filter_prefix        = "uploads/"
#   }
#   depends_on = [aws_lambda_permission.allow_s3]
# }

output "attachments_bucket" {
  value = aws_s3_bucket.attachments.bucket
}