# 10 — Milestone 8: Harden and prove it (Days 9-10)

## 1. Walk the full checklist for real

Go through [CHECKLIST.md](./CHECKLIST.md) top to bottom. For every item, run the verification command listed — don't tick anything from memory. Fix anything that fails before moving on.

## 2. Confirm tagging (should already be done — verify it, don't redo it)

Tagging was solved structurally on Day 3 via `default_tags` in `infra/providers.tf`, so there's nothing new to do here except prove it:

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=TicketDesk \
  --region ap-south-1 \
  --query "ResourceTagMappingList[].ResourceARN" | wc -l
```

Should return a count roughly matching your resource total. Spot-check a few ARNs for all four tags (`Project`, `Owner`, `Environment`, `CostCenter`).

## 3. Run the smoke suite and the load sanity check

Smoke suite: this already runs automatically on every push (Milestone 6). Trigger it once more deliberately and screenshot the green run for your evidence.

Load check:

```bash
chmod +x scripts/load-test.sh
./scripts/load-test.sh $(terraform output -raw cloudfront_url)
```

You're checking for **zero errors** at 20 concurrent users over 5 minutes — not a percentile target. If you see non-200 responses, stop and read the ECS task logs before changing anything (this is the Day 1 advice from the brief, and it applies here more than anywhere).

## 4. Produce the cost report

Fill in [cost-report-template.md](./cost-report-template.md) using real numbers from **AWS Cost Explorer** (Billing → Cost Explorer → group by Service, date range = your project's actual working days), cross-checked against the estimates in [COST_NOTES.md](./COST_NOTES.md). Rename your filled-in copy to `docs/COST_REPORT.md` when done — that's the actual deliverable, the template stays as a template for reference.

## 5. The real test: destroy and rebuild from zero, while someone watches

```bash
terraform destroy
```

Confirm with `aws elbv2 describe-load-balancers`, `aws ecs list-clusters`, `aws rds describe-db-instances`, `aws lambda list-functions` — everything under your prefix should be gone (pass/fail gate 5).

```bash
terraform apply
```

Then walk through the verification steps from Milestones 2 through 7 again in sequence: ALB responds, ticket persists across a forced redeploy, CloudFront serves the frontend, an attachment produces a thumbnail, a push to `main` deploys automatically, and the dashboard/alarms are live.

**Done when:** your pod runs `terraform destroy`, then `terraform apply`, and the entire app comes back working end to end — while a facilitator watches. Everything in this repo has been built so that this is genuinely just those two commands, not "destroy, apply, then quietly fix three things that only worked because I'd clicked something once."

## 6. Final pass on the five pass/fail gates

Don't let scoring math distract from these — any one failing caps your grade regardless of everything else. Re-read `docs/CHECKLIST.md`'s final section and check each one explicitly, one more time, on the freshly-rebuilt stack (not the one you tore down five minutes ago — the *new* one).
