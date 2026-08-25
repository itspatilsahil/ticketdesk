# 04 — Milestone 2: Infrastructure as code (Day 3)

Today you rebuild exactly what you clicked through by hand on Day 1 — VPC, subnets, security groups, ALB, ECS cluster/task/service — except this time it's Terraform, and it's reproducible.

## 1. Bootstrap the remote state backend (one-time)

```bash
cd ticketdesk/infra/bootstrap
terraform init
terraform apply -var="owner_initials=<initials>"
```

Note the two outputs (`state_bucket`, `lock_table`). This bootstrap config keeps its own small local state file — that's expected, it's the one exception, because it creates the very backend everything else stores its state in.

## 2. Configure the main stack's backend and variables

```bash
cd ../
cp backend.hcl.example backend.hcl
# edit backend.hcl: replace <initials> in bucket and dynamodb_table with your own

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: owner_initials, and container_image (the ECR URI:SHA you pushed in Milestone 1)
```

## 3. Init and bring the Milestone 0 ECR repo under management

```bash
terraform init -backend-config=backend.hcl
terraform import aws_ecr_repository.api tkt-<initials>-api
```

`terraform plan` afterward should show Terraform creating everything *except* the ECR repo (which now shows as already-managed, possibly with a small diff if `IMMUTABLE` tag mutability wasn't set by hand — that's fine, it'll just update it in place).

## 4. Plan, then apply

```bash
terraform plan
```

Read the plan output before applying anything — this is the single most useful habit in this whole POC. Count the resources: you should see roughly 20-25 resources being created (VPC, 4 subnets, IGW, 2 route tables + associations, NAT instance + its security group, ALB + listener + target group, 2 security groups, ECS cluster, task definition, service, 2 IAM roles + attachment, log group).

```bash
terraform apply
```

Type `yes` when prompted. This takes 3-5 minutes — the NAT instance and the ECS service both need to actually boot.

## 5. Verify

```bash
terraform output alb_dns_name
curl -s http://$(terraform output -raw alb_dns_name)/actuator/health
curl -s http://$(terraform output -raw alb_dns_name)/api/tickets
```

Also check in the console that the ECS task is in a **private** subnet with no public IP (EC2 → Network Interfaces, or ECS → task → Configuration tab) — this is the difference from Day 1 that matters most.

## 6. Prove it's actually reproducible — this is the real point of the milestone

```bash
terraform destroy
```

Type `yes`. Wait for it to finish (the NAT instance and ALB take the longest). Then:

```bash
terraform apply
```

again, and repeat the curl checks from step 5. If this round-trips cleanly, checklist item 9 and pass/fail gate 4 are both satisfied for real, not just in theory.

**Cost note:** every hour this stack is up costs you roughly ALB $0.0225 + Fargate ~$0.01 (0.25 vCPU/0.5GB) ≈ $0.03/hr, and the NAT instance is free-tier EC2 hours. Get in the habit from today: `terraform destroy` at the end of every session unless you're actively using the stack. See [COST_NOTES.md](./COST_NOTES.md) for the full breakdown.

**Done when:** `terraform apply` from a clean slate produces a working ALB URL, and `terraform destroy` removes it completely (verify with `aws elbv2 describe-load-balancers` and `aws ecs list-clusters` — both should show nothing under your prefix afterward).

Next: [05 — Milestone 3: database and secrets](./05-milestone-3-database-and-secrets.md)
