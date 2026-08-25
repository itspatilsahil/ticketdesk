resource "aws_db_subnet_group" "main" {
  name       = "tkt-${var.owner_initials}-db-subnets"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "tkt-${var.owner_initials}-db-subnets" }
}

resource "aws_security_group" "rds" {
  name        = "tkt-${var.owner_initials}-rds-sg"
  description = "RDS - only reachable from the ECS task security group, never from a raw CIDR"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from the API task only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_task.id]
  }

  tags = { Name = "tkt-${var.owner_initials}-rds-sg" }
}

resource "aws_db_instance" "main" {
  identifier     = "tkt-${var.owner_initials}-db"
  engine         = "postgres"
  instance_class = "db.t3.micro" # free-tier eligible for 12 months on a new account

  allocated_storage = 20 # stays inside the free-tier 20GB ceiling
  storage_type       = "gp2"
  storage_encrypted  = true # checklist item 20

  db_name  = "ticketdesk"
  username = "ticketdesk_app"

  # RDS creates and manages the master password in Secrets Manager itself -
  # no random_password resource, no password ever typed or stored by us.
  # This is checklist item 17 satisfied by AWS's own mechanism rather than
  # something we hand-roll.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # checklist item 16 / pass-fail gate 3
  multi_az                = false # single-AZ keeps this on the free tier; fine for a POC

   # Free-tier-restricted accounts cap backup retention below 7 days (AWS
  # returns FreeTierRestrictionError above that) - 1 day is the smallest
  # non-zero value, which is all checklist item 21 actually requires
  # ("backups enabled", not any particular retention length).
  backup_retention_period = 1
  apply_immediately        = true

  # skip_final_snapshot=true is a POC-only convenience so `terraform destroy`
  # actually finishes cleanly (pass/fail gate 5). A real production database
  # would set this false and keep deletion_protection on.
  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = "tkt-${var.owner_initials}-db" }
}
