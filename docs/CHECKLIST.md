# Deployment Readiness Checklist — verification guide

The 34 items from the POC brief, each with exactly how this project satisfies it and the command (or console check) to prove it on demo day. Print this, tick items off as you verify them for real — not from memory.

## Container

1. **Multi-stage Dockerfile** — `backend/Dockerfile`, two `FROM` lines. Verify: `grep -c FROM backend/Dockerfile` → `2`.
2. **Runs as non-root** — `USER ticketdesk` before `ENTRYPOINT`. Verify: `docker run --rm <image> whoami` → `ticketdesk`.
3. **No SDK/compiler/build tools in final image** — stage 2 is `eclipse-temurin:21-jre-alpine`, a JRE only. Verify: `docker run --rm <image> which mvn javac` → both empty.
4. **Tagged with git commit SHA, not `latest`** — every push in the docs tags with `$(git rev-parse --short HEAD)`. Verify: `aws ecr describe-images --repository-name tkt-<initials>-api --region ap-south-1 --query 'imageDetails[].imageTags'`.
5. **Image scanning enabled on ECR** — set at repo creation (M0) and in `infra/ecr.tf`. Verify: ECR console → repository → Scan status column populated.

## Infrastructure as code

6. **All infrastructure in Terraform, nothing by hand** — everything in `infra/` except the Day 1 ECR repo, which is `terraform import`-ed in Milestone 2. Verify: `terraform plan` after import shows no unmanaged drift.
7. **Remote state backend with locking** — `infra/versions.tf`'s `backend "s3"` block + DynamoDB table from `infra/bootstrap/`. Verify: `aws s3 ls s3://tkt-<initials>-tfstate/ticketdesk/`.
8. **No hardcoded values that should be variables** — see `infra/variables.tf`; region, sizes, CIDRs, counts are all variables.
9. **`terraform destroy` then `terraform apply` rebuilds successfully** — done explicitly at the end of Milestone 2 and again in Milestone 8.

## Network and compute

10. **App container in a private subnet** — `aws_ecs_service.api`'s `network_configuration` uses `aws_subnet.private[*]`, `assign_public_ip = false`.
11. **Only the ALB in a public subnet** — `aws_lb.main` uses `aws_subnet.public[*]`; the NAT instance is also public (it has to be, to reach the internet) but is not the application.
12. **Security groups reference security groups, not `0.0.0.0/0`** — `infra/security_groups.tf`: ALB→ECS and ECS←ALB both use `security_groups = [...]`, never a CIDR, for anything except the ALB's own public-facing inbound rule (which is meant to be public).
13. **Health check configured, target group healthy** — `/actuator/health` in `infra/alb.tf`'s target group. Verify: EC2 console → Target Groups → Targets tab → `healthy`.
14. **At least two AZs** — `var.azs` has two entries, every subnet resource is `count`-ed across them.
15. **Reachable through the load balancer URL** — `terraform output alb_dns_name`, curl it.

## Database and configuration

16. **Private subnet, `publicly_accessible = false`** — `infra/milestones/m3-database-and-secrets/rds.tf`. Verify: `aws rds describe-db-instances --query "DBInstances[].PubliclyAccessible"`.
17. **DB password in Secrets Manager** — `manage_master_user_password = true`; AWS creates and rotates it, nobody ever sees the value.
18. **App config in Parameter Store, read at runtime** — `aws_ssm_parameter.db_host/port/name/username`, injected via the task definition's `secrets` block.
19. **No credentials anywhere in the repo, verified by scan** — enforced every push by the gitleaks step in `.github/workflows/deploy.yml`. Manual check: `git log -p | grep -i password` should turn up nothing but the string `DB_PASSWORD` (a variable name, not a value).
20. **Encryption at rest on DB and buckets** — `storage_encrypted = true` on the RDS instance; `aws_s3_bucket_server_side_encryption_configuration` on both S3 buckets.
21. **Automated backups, non-zero retention** — `backup_retention_period = 7` on the RDS instance.

## Frontend and serverless

22. **Frontend via CloudFront, S3 not public** — `infra/milestones/m4-frontend/frontend.tf`, OAC-only bucket policy, full public-access block. Verify: direct `https://<bucket>.s3.<region>.amazonaws.com/index.html` request fails.
23. **Attachments via presigned URL, not through the API** — `AttachmentController.presign()` returns a URL the browser uploads to directly; verify with `read_network_requests`-style inspection or simply that the API process never logs the file's bytes.
24. **Lambda triggered by S3 upload, working end to end** — `aws_s3_bucket_notification.attachments` → `aws_lambda_function.thumbnail`. Verify: upload a file, check `s3 ls s3://.../thumbnails/...` a few seconds later.

## Pipeline

25. **Push to `main` deploys with no manual AWS steps** — `.github/workflows/deploy.yml`, OIDC role, no stored AWS keys.
26. **Failing test/secret-scan blocks deployment** — `deploy` job has `needs: build-test-scan`; proven deliberately in Milestone 6 step 5.
27. **Smoke test runs after deploy** — the `smoke-test` job, `needs: deploy`.

## Operations

28. **Logs in CloudWatch, finite retention** — `var.log_retention_days` (default 3) on every log group created.
29. **Dashboard: requests, errors, latency, CPU/memory, DB connections** — `infra/milestones/m7-observability/observability.tf`, six widgets, exactly these metrics.
30. **Three working alarms, wired to a notification target** — the same file, `aws_sns_topic.alerts` + email subscription; tested for real in Milestone 7 step 3.

## Housekeeping

31. **Every resource tagged: Project, Owner, Environment, CostCenter** — `infra/providers.tf`'s `default_tags` block applies these automatically to every resource the AWS provider creates, so there's nothing to remember per-resource. Verify: `aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=TicketDesk --region ap-south-1`.
32. **IAM task role scoped, no `"*"`/`"*"`** — `aws_iam_role.ecs_task` starts empty (M2), gains exactly two scoped inline policies (M3's Secrets/Parameter read via the execution role, M5's S3 put/get on one bucket). Verify: read every `jsonencode({...})` policy block in `infra/` and confirm every `Resource` is a specific ARN, never `"*"`.
33. **Spend within budget, one-page cost report** — see [COST_NOTES.md](./COST_NOTES.md) and [cost-report-template.md](./cost-report-template.md).
34. **README a new joiner could follow from scratch** — the top-level [README.md](../README.md) plus this `docs/` sequence.

## The 5 pass/fail gates — check these explicitly, don't assume

1. No credentials committed — gitleaks in CI, plus a manual `git log -p | grep -iE "password|secret|BEGIN.*KEY"` before every milestone sign-off.
2. No IAM policy with `"Action":"*"` on `"Resource":"*"` — grep every `.tf` file in `infra/` for `"*"` and manually confirm each hit is either an AWS-managed policy ARN (fine) or an action that AWS itself has no resource-level permissions for (documented inline where used, e.g. `ecr:GetAuthorizationToken`).
3. Database not reachable from the internet — `aws rds describe-db-instances --query "DBInstances[].PubliclyAccessible"` → `false`, **and** the RDS security group only allows the ECS task security group in.
4. Stack rebuilds from zero via documented commands — literally `terraform destroy && terraform apply`, done twice over the course of the project (Milestone 2, Milestone 8), not just claimed.
5. `terraform destroy` leaves nothing billable — `aws elbv2 describe-load-balancers`, `aws ecs list-clusters`, `aws rds describe-db-instances`, `aws lambda list-functions`, `aws ec2 describe-instances --filters "Name=tag:Project,Values=TicketDesk"` should all come back empty for anything under your prefix.
