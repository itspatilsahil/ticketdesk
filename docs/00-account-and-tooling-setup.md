# 00 — One-time account and tooling setup

Do this once, before Day 1. Region for everything in this project: **ap-south-1 (Mumbai)**.

## 1. Secure the root user

1. Sign in to the AWS Console as the root user (the email you signed up with).
2. Top-right menu → **Security credentials** → turn on **MFA** for root. Use an authenticator app.
3. Never use root again after this step except for account-level emergencies. Everything else below uses an IAM user.

## 2. Set a budget alert before you create anything else

This is the single most important step for the cost side of the POC — do it before you touch ECS/RDS/ALB.

1. Console → search **Budgets** → **Create budget**.
2. Choose **Customize (advanced)** → **Cost budget**.
3. Period: Monthly. Amount: **$5** (generous headroom over what this project should cost — the point is to catch a mistake, e.g. a NAT Gateway or RDS instance left running, not to cap normal spend).
4. Add an alert threshold at **50%** and **80%** of budget, actual cost, notify your own email.
5. Create the budget.

## 3. Create an IAM user for yourself (stop using root)

1. Console → **IAM** → **Users** → **Create user**. Name: `<your-initials>-admin` (e.g. `sp-admin`).
2. Attach policy **AdministratorAccess** directly for now.

   > This is a deliberate shortcut for a personal learning account, not something you'd do on a real team account. The checklist's IAM requirement (item 32: "no `*` with `*`") applies to the **ECS task role** your application runs as — that one we scope tightly in Milestone 3. Your own human IAM user having broad access on your own single-person free-tier account is a reasonable tradeoff; note this explicitly in your write-up if asked.

3. Create the user, then go to the user → **Security credentials** tab → **Create access key** → choose **Command Line Interface (CLI)** → create it. **Download the CSV or copy both values now** — the secret key is shown once only.
4. Also enable console password + MFA for this user if you'll use the console UI (you will, for M0).

## 4. Install and configure the AWS CLI

```bash
# macOS
brew install awscli

# Windows (PowerShell, run as admin)
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
```

Then configure it with the access key from step 3:

```bash
aws configure
# AWS Access Key ID: <paste>
# AWS Secret Access Key: <paste>
# Default region name: ap-south-1
# Default output format: json
```

Verify:

```bash
aws sts get-caller-identity
```

You should see your account ID and the `sp-admin` user ARN.

## 5. Install local dev tools

| Tool | Why | Check |
|---|---|---|
| Java 21 (Temurin) | build the Spring Boot app | `java -version` |
| Maven 3.9+ | build the jar | `mvn -version` |
| Docker Desktop (or Docker Engine) | build/run the container | `docker version` |
| Terraform ≥ 1.7 | Milestone 2 onward | `terraform version` |
| git | version control, and required for the git-SHA image tag in Milestone 1 | `git --version` |

## 6. Initialize your own repo

```bash
cd ticketdesk
git init
git add -A
git commit -m "Initial scaffold: minimal TicketDesk API"
```

Push it to a GitHub repo you own — you'll need this for Milestone 6 (CI/CD). Do **not** commit `~/.aws/credentials` or any `.env` file with real secrets; the `.gitignore` already excludes build output, but double-check before every commit, especially once Milestone 3 introduces a database password.

## 7. Naming convention — use it everywhere from now on

Every AWS resource you create gets the prefix `tkt-<your-initials>-`, e.g. `tkt-sp-cluster`, `tkt-sp-alb`, `tkt-sp-api-repo`. This is how a facilitator (and you, six months from now) can tell your resources apart from anyone else's in a shared account, and it's what the checklist and pass/fail gates assume.

Next: [01 — Build and test the app locally](./01-local-build-and-test.md)
