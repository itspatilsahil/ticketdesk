variable "owner_initials" {
  description = "Your initials - used as the resource name prefix tkt-<initials>-*"
  type        = string
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "cost_center" {
  type    = string
  default = "poc-training"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

# Two AZs is the checklist minimum (item 14) and the cheapest way to get
# real redundancy - a third AZ would mean a third NAT-instance failure
# domain to think about for no POC-level benefit.
variable "azs" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "container_image" {
  description = "Full ECR image URI including tag, e.g. <account>.dkr.ecr.ap-south-1.amazonaws.com/tkt-sp-api:abc1234"
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

# Smallest size Fargate allows - cheapest possible per-hour rate and
# plenty for this app (see docs/COST_NOTES.md for the pricing math).
variable "fargate_cpu" {
  type    = number
  default = 256
}

variable "fargate_memory" {
  type    = number
  default = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "log_retention_days" {
  type    = number
  default = 3
}

# t3.micro / t4g.micro rides on the same 750 free-tier EC2 hours everyone
# gets for 12 months on a new account, unlike a managed NAT Gateway which
# bills from hour zero. See docs/COST_NOTES.md for the full comparison.
variable "nat_instance_type" {
  type    = string
  default = "t3.micro"
}
