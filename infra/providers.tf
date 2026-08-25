provider "aws" {
  region = var.aws_region

  # Every resource this provider creates is tagged automatically -
  # this is what satisfies checklist item 31 without having to remember
  # to tag each resource individually.
  default_tags {
    tags = {
      Project     = "TicketDesk"
      Owner       = var.owner_initials
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  }
}
