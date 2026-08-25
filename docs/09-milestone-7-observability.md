# 09 — Milestone 7: Observability (Day 8)

## 1. Add the Terraform

```bash
cd ticketdesk/infra
cp milestones/m7-observability/observability.tf .
```

Add to `terraform.tfvars`:

```
alert_email = "<an email address your whole pod can check>"
```

```bash
terraform plan
terraform apply
```

**Immediately check that inbox** — AWS SNS sends a confirmation email ("AWS Notification - Subscription Confirmation"). Click **Confirm subscription**. Alarms will fire silently into the void until this is done; it's an easy thing to forget and then wonder why "nothing happened" during the demo.

## 2. Look at the dashboard

```bash
terraform output dashboard_url
```

Six widgets: request count, 5xx error rate, p99 response time, ECS CPU/memory, RDS connections, unhealthy target count. Generate a bit of traffic first so the graphs aren't empty:

```bash
for i in $(seq 1 30); do curl -s $(terraform output -raw cloudfront_url)/api/tickets > /dev/null; done
```

## 3. Prove the alarms actually work — don't just trust that they're wired correctly

**5xx alarm:** temporarily point the target group at a wrong port (or stop the ECS service) to generate real 5xx responses, or simpler — ask a podmate to hit a nonexistent AWS Fargate task count of 0 for a minute:

```bash
aws ecs update-service --cluster tkt-<initials>-cluster --service tkt-<initials>-svc --desired-count 0 --region ap-south-1
```

Watch: **unhealthy targets** alarm should go into ALARM state within ~2 minutes (all targets deregistered), and CloudFront requests should start returning errors, tripping the 5xx alarm too. You should get an email for both. Then restore:

```bash
aws ecs update-service --cluster tkt-<initials>-cluster --service tkt-<initials>-svc --desired-count 1 --region ap-south-1
```

**High DB CPU alarm:** the honest way to test this without actually hammering the database is to temporarily lower the threshold in `observability.tf` (e.g. from 80 to 1), `terraform apply`, confirm the email arrives, then set it back to 80 and `apply` again. Note in your log that you tested it this way and why — that's a legitimate testing technique, not a shortcut, and worth being able to explain.

**Done when:** a facilitator can stop your service (or otherwise break it) without telling you, and you find out from an email alert — not from them telling you, and not by staring at the dashboard waiting for something to look wrong.

Next: [10 — Milestone 8: harden and prove it](./10-milestone-8-harden-and-prove-it.md)
