# "Other config lives in Parameter Store" - the non-secret connection
# details. Only DB_PASSWORD (handled entirely by RDS + Secrets Manager in
# rds.tf) is a secret; everything here is fine to read in plaintext.

resource "aws_ssm_parameter" "db_host" {
  name  = "/tkt-${var.owner_initials}/db/host"
  type  = "String"
  value = aws_db_instance.main.address
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/tkt-${var.owner_initials}/db/port"
  type  = "String"
  value = tostring(aws_db_instance.main.port)
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/tkt-${var.owner_initials}/db/name"
  type  = "String"
  value = aws_db_instance.main.db_name
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/tkt-${var.owner_initials}/db/username"
  type  = "String"
  value = aws_db_instance.main.username
}

# --- Who actually needs permission to read these? -----------------------
#
# The values in the task definition's "secrets" block (see the ecs.tf
# replacement in this folder) are resolved by the ECS AGENT before your
# container even starts, using the task's EXECUTION role - not the task
# role. Your application code never calls Secrets Manager or SSM itself
# here; it just sees plain environment variables. That's the native ECS
# "secrets" mechanism, and it's why this policy is attached to
# aws_iam_role.ecs_execution, not aws_iam_role.ecs_task.
#
# (The task role stays reserved for permissions your APPLICATION CODE
# calls directly - which starts in Milestone 5, when it needs to generate
# S3 presigned URLs itself.)
#
# Either way, note both are scoped to specific resource ARNs, never "*" -
# checklist item 32 / pass-fail gate 2.

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "tkt-${var.owner_initials}-ecs-execution-secrets"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ssm:GetParameters"]
        Resource = [
          aws_ssm_parameter.db_host.arn,
          aws_ssm_parameter.db_port.arn,
          aws_ssm_parameter.db_name.arn,
          aws_ssm_parameter.db_username.arn,
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_db_instance.main.master_user_secret[0].secret_arn]
      }
    ]
  })
}
