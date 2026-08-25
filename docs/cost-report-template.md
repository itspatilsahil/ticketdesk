# TicketDesk — Cost Report

*(Fill in and keep to one page. Numbers marked "Actual" come from AWS Cost Explorer — Billing → Cost Explorer → group by Service, filter the date range to this project. Numbers marked "Estimate" are for sanity-checking Actual, not a substitute for it.)*

**Project:** TicketDesk POC | **Owner:** \<your initials\> | **Region:** ap-south-1 | **Period:** \<Day 1 date\> – \<Day 10 date\>

## Total spend

| | Amount |
|---|---|
| Total actual spend (Cost Explorer, filtered to this account/period) | $\_\_\_\_ |
| Budget alert threshold set (see docs/00) | $5.00/month |
| Went over budget? | Yes / No — if yes, explain what happened and what you'd change |

## Spend by service

| Service | Estimate (see docs/COST_NOTES.md) | Actual (Cost Explorer) | Notes |
|---|---|---|---|
| ECS Fargate | ~$1-3 (compute hours × sessions actually run) | $\_\_\_\_ | 0.25 vCPU / 0.5GB, destroyed between sessions |
| Application Load Balancer | ~$2-4 | $\_\_\_\_ | Only genuinely-not-free hourly-billed piece besides NAT |
| RDS (db.t3.micro) | $0 (free tier) | $\_\_\_\_ | Confirm this actually shows $0 — if not, check you only have one RDS instance on the account |
| NAT instance (EC2 t3.micro) | $0 (free tier) | $\_\_\_\_ | Compare against what a NAT Gateway would have cost (see below) |
| S3 (frontend + attachments + Terraform state) | ~$0.10 | $\_\_\_\_ | |
| CloudFront | $0 (free tier) | $\_\_\_\_ | |
| Lambda (thumbnail) | $0 (always-free tier) | $\_\_\_\_ | |
| Secrets Manager | ~$0.20 (half a month, one secret) | $\_\_\_\_ | The one deliberately non-free item the brief names by name |
| CloudWatch (logs + dashboard + alarms) | ~$0.05 | $\_\_\_\_ | Retention capped at \<N\> days |
| **Total** | | **$\_\_\_\_** | |

## The two most expensive things

1. **\_\_\_\_\_\_\_\_\_\_\_\_** — $\_\_\_\_ — why: \_\_\_\_\_\_\_\_\_\_\_\_
2. **\_\_\_\_\_\_\_\_\_\_\_\_** — $\_\_\_\_ — why: \_\_\_\_\_\_\_\_\_\_\_\_

## Deliberate cost tradeoffs made (and why)

- **NAT instance instead of NAT Gateway.** A managed NAT Gateway would have cost roughly $0.045/hr × hours-up + per-GB data processing — for a stack left up continuously across the two weeks (~336 hrs), that's $15+ before data charges. The self-managed NAT instance rides on free-tier EC2 hours instead. Tradeoff: no managed HA, I patch it myself — acceptable for a POC with no production traffic, not how I'd do this on a real team project.
- **Destroy-between-sessions habit.** Both Fargate and the ALB bill hourly regardless of traffic; running only during active work sessions instead of continuously kept these two line items to roughly $\_\_\_\_ total instead of an estimated $\_\_\_\_ if left running the full two weeks.
- \<add any others you made — e.g. single-AZ RDS instead of Multi-AZ, smallest Fargate task size, log retention length\>

## What I'd do differently on a real (non-training) project

\<2-3 sentences — e.g., NAT Gateway for HA, Multi-AZ RDS, longer log retention with a lifecycle policy to S3/Glacier instead of a short hard cutoff, etc.\>
