# 05 — Milestone 3: Database and secrets (Day 4)

## 1. Add the new Terraform files

```bash
cd ticketdesk/infra
cp milestones/m3-database-and-secrets/rds.tf .
cp milestones/m3-database-and-secrets/secrets.tf .
```

`ecs.tf` needs to change too (new `environment`/`secrets` blocks on the task definition). Diff it first so you actually see what's different, then copy it over:

```bash
diff ecs.tf milestones/m3-database-and-secrets/ecs.tf
cp milestones/m3-database-and-secrets/ecs.tf .
```

## 2. Understand what you're about to create, before applying

Read `rds.tf` and `secrets.tf` fully — this is exactly the kind of block a facilitator will ask you to explain on demo day. Two things worth understanding before you type `apply`:

- **`manage_master_user_password = true`** — RDS creates and rotates the master password in Secrets Manager itself. You never generate, see, or store the password anywhere. That's what makes checklist item 17 and pass/fail gate 1 (no credentials committed) trivially true here — there's no password-shaped value in this repo at all.
- **Execution role vs. task role** — the four SSM parameters and the one Secrets Manager secret are attached to `aws_iam_role.ecs_execution`, not `aws_iam_role.ecs_task`. That's because the ECS *agent* resolves the task definition's `secrets` block before your container even starts — your Spring Boot code never touches the AWS SDK for this. The task role stays empty until Milestone 5, when your application code itself needs to call S3 directly.

## 3. Plan and apply

```bash
terraform plan
```

You should see roughly 8-10 new resources (DB subnet group, RDS security group, the RDS instance itself, 4 SSM parameters, the execution-role policy) and one resource changed in place (the task definition, because its container definition changed).

```bash
terraform apply
```

This one takes longer than Milestone 2 — RDS instance creation is typically 5-10 minutes. Fargate will keep serving the *old* task definition (still on H2) until the new one is healthy, so there's no downtime while you wait.

## 4. Verify persistence — this is the actual test

```bash
ALB=$(terraform output -raw alb_dns_name)

curl -s -X POST http://$ALB/api/tickets \
  -H "Content-Type: application/json" \
  -d '{"title":"Persistence check","description":"Should survive a restart","category":"SOFTWARE","priority":"MEDIUM"}'

curl -s http://$ALB/api/tickets
```

Note the ticket's `id`. Now force a fresh task (simulates a restart):

```bash
aws ecs update-service --cluster tkt-<initials>-cluster --service tkt-<initials>-svc --force-new-deployment --region ap-south-1
```

Wait a couple of minutes for the new task to become healthy, then:

```bash
curl -s http://$ALB/api/tickets
```

**Done when:** the ticket you created is still there after the forced restart, and:

```bash
git grep -i "password" -- . ':!docs' ':!*.md'
```

returns nothing that looks like an actual credential (env var *names* like `DB_PASSWORD` are fine and expected — an actual password string is not).

## 5. Confirm the pass/fail gate

```bash
aws rds describe-db-instances --region ap-south-1 \
  --query "DBInstances[?DBInstanceIdentifier=='tkt-<initials>-db'].PubliclyAccessible"
```

Must print `false`. This is pass/fail gate 3 — get this wrong and it caps your grade regardless of everything else, so don't skip checking it directly rather than assuming the Terraform config did the right thing.

Next: [06 — Milestone 4: frontend](./06-milestone-4-frontend.md)
