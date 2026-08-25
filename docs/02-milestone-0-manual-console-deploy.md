# 02 — Milestone 0: Deploy it by hand (Day 1)

Goal: get TicketDesk running on ECS Fargate behind a load balancer, using **only the AWS Console** — no Terraform, no scripts beyond pushing the image. You will feel every click. That's the point. Everything you build today gets **deleted at the end of the day** (Section 9) and rebuilt properly in Terraform on Day 3.

To keep today free of NAT Gateway costs, we use the **default VPC's public subnets** for both the load balancer and the Fargate task, with the task given a temporary public IP so it can reach ECR and the internet directly — no NAT needed. Milestone 2 (Terraform) is where the app moves into a real private subnet behind a NAT instance. Note this consciously in your log: today's network layout does **not** yet satisfy checklist items 10/11 (private subnet) — that's expected, it's fixed in three days.

Replace `<initials>` with your own initials everywhere below (e.g. `sp`).

---

## 1. Push the image to ECR

**Console:**
1. ECR → **Repositories** → **Create repository**.
2. Visibility: Private. Name: `tkt-<initials>-api`.
3. **Enable** "Scan on push" (this satisfies checklist item 5 — do it now, it costs nothing extra).
4. Create.
5. Click the repository → **View push commands** and note your repository URI, it looks like:
   `<account-id>.dkr.ecr.ap-south-1.amazonaws.com/tkt-<initials>-api`

**Terminal:**
```bash
cd ticketdesk/backend
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com

docker build -t tkt-<initials>-api .

# Tag with the git commit SHA, not "latest" (checklist item 4) - even on Day 1
SHA=$(git rev-parse --short HEAD)
docker tag tkt-<initials>-api:latest <account-id>.dkr.ecr.ap-south-1.amazonaws.com/tkt-<initials>-api:$SHA

docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/tkt-<initials>-api:$SHA
echo "Pushed tag: $SHA"
```

Write down the tag you pushed — you'll need it in step 6.

## 2. Find your default VPC's public subnets

Console → **VPC** → **Your VPCs** → note the default VPC ID. → **Subnets** → filter by that VPC ID → note **two subnet IDs in two different Availability Zones** (e.g. one in `ap-south-1a`, one in `ap-south-1b`). Every default-VPC subnet is public (has an internet gateway route), which is exactly what we want for both the ALB and, just for today, the task.

## 3. Create two security groups

Console → **EC2** → **Security Groups** → **Create security group**, twice:

**`tkt-<initials>-alb-sg`**
- VPC: default
- Inbound: HTTP (80) from `0.0.0.0/0` — this one is genuinely meant to be public
- Outbound: leave default (all traffic)

**`tkt-<initials>-ecs-sg`**
- VPC: default
- Inbound: Custom TCP, port `8080`, source = **the `tkt-<initials>-alb-sg` security group** (type its name/ID in the source field, not an IP range — this is what satisfies checklist item 12, "security groups reference other security groups, not 0.0.0.0/0")
- Outbound: leave default (all traffic — the task needs this today to reach ECR and the internet directly, since it has no NAT yet)

## 4. Create a target group

Console → **EC2** → **Target Groups** → **Create target group**.
- Target type: **IP addresses** (required for Fargate)
- Protocol: HTTP, Port: 8080
- VPC: default
- Health check path: `/actuator/health`
- Advanced health check settings: success codes `200`, healthy threshold 2, interval 15s (defaults are fine)
- Name: `tkt-<initials>-tg`
- Skip "Register targets" for now (ECS will register the task automatically) → Create.

## 5. Create the Application Load Balancer

Console → **EC2** → **Load Balancers** → **Create** → **Application Load Balancer**.
- Name: `tkt-<initials>-alb`
- Scheme: Internet-facing
- VPC: default, select **both** public subnets from step 2
- Security group: **remove** the default one, attach `tkt-<initials>-alb-sg` only
- Listener: HTTP : 80 → forward to `tkt-<initials>-tg`
- Create. Wait for state = **Active** (a minute or two). Note the ALB's DNS name.

## 6. Create the ECS cluster

Console → **ECS** → **Clusters** → **Create cluster**.
- Name: `tkt-<initials>-cluster`
- Infrastructure: **AWS Fargate (serverless)** only
- Create.

## 7. Create the task definition

Console → **ECS** → **Task definitions** → **Create new task definition**.
- Family: `tkt-<initials>-api-task`
- Launch type: **AWS Fargate**
- OS/Arch: Linux/X86_64
- CPU: **0.25 vCPU**, Memory: **0.5 GB** — smallest size Fargate allows, plenty for this app, and the cheapest possible per-hour rate.
- Task execution role: let it auto-create `ecsTaskExecutionRole` (this is what lets ECS itself pull the image and write logs — separate from the *task role*, which is what your *application code* uses, and which we deliberately leave empty today; that gets scoped in Milestone 3 when the app needs to read Secrets Manager/Parameter Store).
- Container:
  - Name: `api`
  - Image URI: `<account-id>.dkr.ecr.ap-south-1.amazonaws.com/tkt-<initials>-api:<the SHA tag from step 1>`
  - Port mappings: container port `8080`, protocol TCP
  - Leave environment variables empty (default profile → H2, nothing to configure yet)
  - Logging: enable **CloudWatch Logs**, log group `/ecs/tkt-<initials>-api`, **set retention to 3 days** when prompted (or edit the log group right after creation — Logs → Log groups → select it → Actions → Edit retention). Don't leave it as "Never expire."
- Create.

## 8. Create the ECS service

Console → your cluster → **Services** tab → **Create**.
- Launch type: Fargate
- Task definition: the one from step 7, latest revision
- Service name: `tkt-<initials>-svc`
- Desired tasks: **1**
- Networking: default VPC, select **both public subnets** from step 2
- Security group: remove default, attach `tkt-<initials>-ecs-sg` only
- **Public IP: turn ON** (required today — no NAT means the task needs its own public IP to reach the internet/ECR; this goes away in Milestone 2)
- Load balancing: Application Load Balancer → existing ALB → container `api:8080` → existing target group `tkt-<initials>-tg`
- Create.

## 9. Verify

1. ECS → cluster → service → **Tasks** tab: wait for the task's **Last status** to become `RUNNING` (1-2 minutes).
2. EC2 → Target Groups → `tkt-<initials>-tg` → **Targets** tab: wait for status `healthy`.
3. Hit the app through the load balancer:

```bash
ALB_DNS=<paste the ALB DNS name from step 5>
curl -s http://$ALB_DNS/actuator/health
curl -s -X POST http://$ALB_DNS/api/tickets \
  -H "Content-Type: application/json" \
  -d '{"title":"Test from ALB","description":"M0 verification","category":"SOFTWARE","priority":"LOW"}'
curl -s http://$ALB_DNS/api/tickets
```

**Done when:** you get a healthy JSON response through the load balancer URL — not localhost.

## 10. Write down every resource you created

This is an explicit "done when" requirement — keep this list, you'll delete against it in Section 9 today and compare it to what Terraform creates automatically on Day 3.

| # | Resource | Name/ID | Notes |
|---|---|---|---|
| 1 | ECR repository | `tkt-<initials>-api` | keep — needed for M1/M2 |
| 2 | Security group | `tkt-<initials>-alb-sg` | delete today |
| 3 | Security group | `tkt-<initials>-ecs-sg` | delete today |
| 4 | Target group | `tkt-<initials>-tg` | delete today |
| 5 | Application Load Balancer | `tkt-<initials>-alb` | delete today — this is the expensive one if left running |
| 6 | ECS cluster | `tkt-<initials>-cluster` | delete today |
| 7 | ECS service | `tkt-<initials>-svc` | delete today (before the cluster) |
| 8 | ECS task definition | `tkt-<initials>-api-task` | deregister today |
| 9 | CloudWatch log group | `/ecs/tkt-<initials>-api` | delete today |
| 10 | `ecsTaskExecutionRole` (IAM) | auto-created | can leave — reused every milestone, costs nothing |

## 11. Teardown — delete everything you created today

Order matters (dependencies must go first):

1. ECS → service → **Update** → desired tasks = 0 → wait for tasks to stop → **Delete service**.
2. ECS → **Delete cluster** `tkt-<initials>-cluster`.
3. ECS → Task definitions → select `tkt-<initials>-api-task` → **Deregister** all revisions.
4. EC2 → Load Balancers → select `tkt-<initials>-alb` → **Delete**. Wait for it to fully disappear (a minute or two) before the next step.
5. EC2 → Target Groups → delete `tkt-<initials>-tg`.
6. EC2 → Security Groups → delete `tkt-<initials>-ecs-sg` then `tkt-<initials>-alb-sg` (ECS one first — the ALB one is referenced by it).
7. CloudWatch → Log groups → delete `/ecs/tkt-<initials>-api`.
8. **Keep** the ECR repository and image — you need the pushed image for Milestone 1/2.

Verify nothing billable is left:

```bash
aws elbv2 describe-load-balancers --region ap-south-1 --query "LoadBalancers[?contains(LoadBalancerName,'tkt-<initials>')]"
aws ecs list-clusters --region ap-south-1
```

Both should return empty for anything under your prefix.

**Pass/fail gate check:** at this point, the database isn't part of the picture yet (that's Milestone 3), so gate #3 ("database not reachable from the internet") isn't applicable today — just don't forget it once RDS exists.

Next: [03 — Milestone 1: containerise properly](./03-milestone-1-containerise.md)
