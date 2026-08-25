# Cost notes and reasoning

Written once, referenced throughout the project, and the backbone of the Milestone 8 cost report. Figures below are general AWS on-demand rates verified against AWS's own pricing pages in August 2026; **ap-south-1 (Mumbai) rates can differ slightly from these** — treat every number here as "what to expect," and use AWS Cost Explorer (Billing → Cost Explorer) plus the [AWS Pricing Calculator](https://calculator.aws) for the exact figures that go in your actual report.

## The services with no free tier, and why they still stay cheap here

| Service | Rate | Why it's still cheap for this project |
|---|---|---|
| Application Load Balancer | ~$0.0225/hr + $0.008/LCU-hr | No free tier at all, bills from hour zero. At light POC traffic the LCU component is negligible; the hourly charge is what to watch — it's a function of **uptime**, not usage. |
| ECS Fargate | ~$0.0405/vCPU-hr, ~$0.0044/GB-hr (Linux/x86) | This project runs the smallest possible task (0.25 vCPU / 0.5GB) — about $0.011/hr total. Also a function of uptime, not usage. |
| Secrets Manager | $0.40/secret/month + tiny per-API-call cost | One secret (the RDS-managed master password). This is the one deliberate non-free line item the brief names specifically — small enough to just accept and document. |

## The one service that can quietly wreck a free-tier budget

**NAT Gateway**: ~$0.045/hr **plus** $0.045/GB processed, billing from the moment it exists — regardless of how little traffic actually flows through it. Left running for the full two weeks (336 hours) that's $15+ before any data charges, on a project whose real traffic is a handful of manual tests and a nightly CI run.

**This project uses a self-managed NAT instance instead** (see `infra/nat.tf`) — a t3.micro EC2 instance running as a NAT, which rides on the same 750 free-tier EC2 hours every new AWS account gets for 12 months. Net cost: effectively $0 for the life of this POC.

**The honest tradeoff, worth stating explicitly in your report:** a NAT Gateway is managed, highly available, and needs zero patching — the right choice in production. A NAT instance is a single point of failure you're responsible for patching, and if it goes down, every private-subnet resource loses outbound connectivity until it's replaced. For a two-week training POC on a personal free-tier account with no production traffic, that tradeoff is clearly worth it. On a real team project, it would not be.

## What stays inside the free tier

- **RDS** (db.t3.micro/t4g.micro, single-AZ, 20GB gp2): 750 free hours/month for 12 months on a new account — covers one instance running continuously all month, as long as it's the only RDS instance on the account.
- **S3**: 5GB free storage, 20,000 GET / 2,000 PUT requests/month for 12 months — nowhere near what this project's attachments or Terraform state will use.
- **Lambda**: 1 million free requests and 400,000 GB-seconds of compute *every month, permanently* (not just 12 months) — the thumbnail function costs nothing at this scale, ever.
- **CloudFront**: 1TB data transfer out and 10 million HTTP/HTTPS requests free per month for 12 months.
- **CloudWatch**: 3 free dashboards, 10 free alarm-metrics — this project uses exactly 1 dashboard and 3 alarms, both inside the free allowance. Log *storage* and *ingestion* are not free, which is why log retention is set to a few days rather than left unset.

## The single biggest lever: uptime, not architecture

Given the two genuinely-not-free services are both billed hourly regardless of traffic, the cheapest possible strategy has nothing to do with instance sizing and everything to do with habit: **`terraform destroy` at the end of every work session.** A stack that's up for 6-8 hours a day and down the rest of the time costs a small fraction of one left running continuously — roughly $1-3 total in Fargate + ALB charges across the whole two-week individual phase, versus $15-20+ if left running around the clock. This is also literally the advice the POC brief itself gives ("destroy and rebuild every day or two") — the cost reasoning and the learning reasoning point at the same habit.

## Setting up the guardrail

Section [00 — account and tooling setup](./00-account-and-tooling-setup.md) has you create an AWS Budgets alert (50%/80% of $5/month) **before** creating any billable resource — this is what catches a mistake (an accidentally-left-running stack, a wrong instance size) within hours instead of at the end of the month.
