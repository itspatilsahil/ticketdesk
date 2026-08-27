# Two different roles, two different jobs (both required, easy to conflate):
#
# - The EXECUTION role is used by the ECS agent itself, before your code
#   ever runs: pulling the image from ECR, writing the container's stdout
#   to CloudWatch Logs. AmazonECSTaskExecutionRolePolicy is an AWS-managed
#   policy scoped tightly to exactly that job - appropriate to reuse as-is.
#
# - The TASK role is what your application code assumes at runtime. It
#   starts empty here; Milestone 3 attaches a policy letting it read one
#   specific secret and one specific Parameter Store path (never "*" on
#   "*" - checklist item 32 / pass-fail gate 2), and Milestone 5 attaches
#   permission to generate presigned URLs for one specific S3 bucket.
resource "aws_iam_role" "ecs_execution" {
  name = "tkt-${var.owner_initials}-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "ecs_task" {
  name = "tkt-${var.owner_initials}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}