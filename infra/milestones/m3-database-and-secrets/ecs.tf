# REPLACES infra/ecs.tf as of Milestone 3. Only the container_definitions
# block changed (added "environment" and "secrets") - everything else is
# identical to the Milestone 2 version. Diff it yourself before copying
# over, so you've actually looked at the one line that matters.

resource "aws_ecs_cluster" "main" {
  name = "tkt-${var.owner_initials}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = { Name = "tkt-${var.owner_initials}-cluster" }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/tkt-${var.owner_initials}-api"
  retention_in_days = var.log_retention_days

  tags = { Name = "tkt-${var.owner_initials}-api-logs" }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "tkt-${var.owner_initials}-api-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.container_image
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]

      # NEW in Milestone 3: switches the app from the default H2 profile
      # to the prod profile (application-prod.yml), which requires these
      # four plain values plus the one secret below.
      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = "prod" }
      ]

      # NEW in Milestone 3: resolved by the ECS agent using the execution
      # role BEFORE the container starts. The app just sees normal env
      # vars (DB_HOST, DB_PORT, DB_NAME, DB_USERNAME, DB_PASSWORD) - it
      # has no idea any of this came from Secrets Manager / Parameter
      # Store. Nothing here is ever written to the repo or to a log line.
      secrets = [
        { name = "DB_HOST", valueFrom = aws_ssm_parameter.db_host.arn },
        { name = "DB_PORT", valueFrom = aws_ssm_parameter.db_port.arn },
        { name = "DB_NAME", valueFrom = aws_ssm_parameter.db_name.arn },
        { name = "DB_USERNAME", valueFrom = aws_ssm_parameter.db_username.arn },
        { name = "DB_PASSWORD", valueFrom = "${aws_db_instance.main.master_user_secret[0].secret_arn}:password::" },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])

  tags = { Name = "tkt-${var.owner_initials}-api-task" }
}

resource "aws_ecs_service" "api" {
  name            = "tkt-${var.owner_initials}-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name    = "api"
    container_port    = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = { Name = "tkt-${var.owner_initials}-svc" }
}
