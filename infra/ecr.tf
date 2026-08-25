# This repository was originally created by hand in Milestone 0's console
# walkthrough. Rather than deleting and losing the pushed image, bring it
# under Terraform management once here:
#
#   terraform import aws_ecr_repository.api tkt-<initials>-api
#
# After the import, `terraform plan` should show no changes (or only the
# scan-on-push setting, if you didn't enable it identically) - that's the
# state you want before moving on. This is how "nothing created by hand"
# (checklist item 6) gets satisfied without throwing away Day 1's work.

resource "aws_ecr_repository" "api" {
  name                 = "tkt-${var.owner_initials}-api"
  image_tag_mutability = "IMMUTABLE" # you tag by git SHA, so a tag should never be overwritten

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "tkt-${var.owner_initials}-api" }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 10 images - controls storage cost as you iterate"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
