# 08 — Milestone 6: CI/CD pipeline (Day 7)

This is the first pod milestone — your pod picks **one** member's deployment as the shared reference from here on. Everything below assumes you're working against that one chosen AWS environment.

## 1. Add the OIDC role Terraform

```bash
cd ticketdesk/infra
cp milestones/m6-cicd/github-oidc.tf .
```

Add the `tls` provider block from `milestones/m6-cicd/versions-additions.tf` into `versions.tf`'s `required_providers`.

Add to `terraform.tfvars`:

```
github_repo = "<your-github-username>/<your-repo-name>"
```

```bash
terraform init -backend-config=backend.hcl   # picks up the new tls provider
terraform plan
terraform apply
terraform output github_actions_role_arn
```

## 2. Configure the GitHub repository

Push this repo to GitHub if you haven't already. Then, in the repo's **Settings → Secrets and variables → Actions → Variables** tab, add three **repository variables** (not secrets — none of these are sensitive, which is itself the point: nothing in this pipeline's configuration needs to be secret because there's no long-lived credential anywhere in it):

| Variable | Value |
|---|---|
| `OWNER_INITIALS` | your initials, e.g. `sp` |
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | the `github_actions_role_arn` output from step 1 |
| `APP_URL` | your CloudFront URL, e.g. `https://d123abc.cloudfront.net` |

## 3. Understand the pipeline before you trigger it

Open `.github/workflows/deploy.yml`. Three jobs, chained by `needs:`:

1. **build-test-scan** — checks out the code, runs `mvn test` (the actual unit tests from Milestone 6's test class), scans the full git history for committed secrets with gitleaks, then builds and pushes the image — all in that order, so a broken test or a leaked credential never even reaches the build step.
2. **deploy** — only runs if job 1 fully succeeds. Fetches the current ECS task definition, swaps in the new image tag, registers a new revision, and updates the service, waiting until ECS reports the new tasks are actually healthy before the job is considered done.
3. **smoke-test** — only runs if the deploy actually succeeded. Hits the real, now-live CloudFront URL and checks both the health endpoint and that creating a ticket actually works.

If step 1 or step 2 fails, step 3 (and everything after it) never runs — that's what "a failing step must block the deployment" means in GitHub Actions terms; you don't need extra logic for it, `needs:` does it.

## 4. Trigger it for real

```bash
# make a trivial, visible change
echo "<!-- ci test $(date) -->" >> frontend/index.html
git add -A
git commit -m "Trigger CI/CD pipeline"
git push origin main
```

Watch it run: GitHub repo → **Actions** tab. Three green checkmarks, in order, with no manual step in between.

## 5. Prove the "blocks on failure" requirement, not just the happy path

Temporarily break a test on purpose (e.g., change an assertion in `TicketControllerTest.java` to expect the wrong status), push it, and confirm: the `build-test-scan` job goes red, and **deploy never starts**. Then revert and push again.

**Done when:** a one-line change to `frontend/index.html`, pushed to `main`, reaches the live CloudFront URL with zero AWS console or CLI commands run by you — and a deliberately broken test provably stops the pipeline before it touches AWS at all.

Next: [09 — Milestone 7: observability](./09-milestone-7-observability.md)
