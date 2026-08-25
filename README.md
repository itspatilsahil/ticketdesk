# TicketDesk

A minimal IT support ticket tracker, built from scratch and deployed on AWS as a two-week capstone POC: containerized, behind a load balancer, database in a private subnet, secrets out of config files, deployed by a pipeline, with logs and alarms, rebuildable from zero with two commands.

Stack: Java 21 / Spring Boot (backend), plain HTML/CSS/JS (frontend, no build step), Terraform (infrastructure), GitHub Actions (CI/CD), AWS ap-south-1 (Mumbai).

## What's in this repo

```
backend/            Spring Boot API (Ticket, Comment, Attachment)
  milestones/m5-.../ staged files added at Milestone 5 (see docs/07)
frontend/            static HTML/CSS/JS - no framework, no bundler
lambda-thumbnail/    S3-triggered thumbnail generator (Python + Pillow)
infra/               Terraform - Milestone 2's baseline, plus staged
  milestones/        additions for M3/M4/M5/M6/M7 (see docs/)
  bootstrap/         one-time remote state backend (S3 + DynamoDB)
scripts/             load-test.sh for Milestone 8
docs/                the full day-by-day runbook - start here
.github/workflows/   the CI/CD pipeline (Milestone 6)
```

## Deploy this from scratch — start here

Follow `docs/` in order. Each file is one day, one milestone, and ends with an explicit "done when" you can verify yourself:

1. [00 — Account and tooling setup](./docs/00-account-and-tooling-setup.md)
2. [01 — Build and run locally](./docs/01-local-build-and-test.md)
3. [02 — Milestone 0: manual console deploy](./docs/02-milestone-0-manual-console-deploy.md)
4. [03 — Milestone 1: containerise](./docs/03-milestone-1-containerise.md)
5. [04 — Milestone 2: infrastructure as code](./docs/04-milestone-2-infrastructure-as-code.md)
6. [05 — Milestone 3: database and secrets](./docs/05-milestone-3-database-and-secrets.md)
7. [06 — Milestone 4: frontend](./docs/06-milestone-4-frontend.md)
8. [07 — Milestone 5: serverless attachments](./docs/07-milestone-5-serverless-attachments.md)
9. [08 — Milestone 6: CI/CD pipeline](./docs/08-milestone-6-cicd-pipeline.md)
10. [09 — Milestone 7: observability](./docs/09-milestone-7-observability.md)
11. [09b — Stretch goals](./docs/09b-stretch-goals.md) (only after everything below is green)
12. [10 — Milestone 8: harden and prove it](./docs/10-milestone-8-harden-and-prove-it.md)

Reference documents, used throughout rather than read once:

- [CHECKLIST.md](./docs/CHECKLIST.md) — all 34 checklist items with the exact command that verifies each one
- [COST_NOTES.md](./docs/COST_NOTES.md) — why each service costs what it costs, and the NAT-instance-instead-of-NAT-Gateway decision
- [cost-report-template.md](./docs/cost-report-template.md) — fill in for the Milestone 8 deliverable

## Design decisions worth knowing before you start

**Two Spring profiles.** `default` (H2, in-memory) is what Milestones 0-2 deploy — no database to provision yet. `prod` (real Postgres, config from env vars) is switched on in Milestone 3 via `SPRING_PROFILES_ACTIVE=prod`. Nothing about the application code changes between them; only environment variables do.

**Staged Terraform and backend code.** `infra/` holds the Milestone 2 baseline (network, ALB, ECS, ECR, IAM). Later milestones' resources live in `infra/milestones/<name>/` until you copy them in on the day they're meant to arrive — same pattern for the Milestone 5 backend additions in `backend/milestones/m5-serverless-attachments/`. This is deliberate: the point of doing this project day-by-day is watching the infrastructure grow in the same order you understand it, not applying a finished stack on day one.

**A NAT instance, not a NAT Gateway.** See [COST_NOTES.md](./docs/COST_NOTES.md) — a documented, deliberate cost tradeoff for a free-tier training account, not an oversight.

**No AWS SDK calls in the app until Milestone 5.** The application only starts talking to AWS directly (to generate presigned S3 URLs) once it actually needs to. Before that, the AWS integration is entirely infrastructure-level (ECS injecting env vars/secrets) — the app code itself doesn't know it's running on AWS.

## Naming convention

Every resource uses the prefix `tkt-<initials>-`. Set your initials once in `infra/terraform.tfvars`.
