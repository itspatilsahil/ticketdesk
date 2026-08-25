# 03 — Milestone 1: Containerise properly (Day 2)

Good news: because the Dockerfile was written correctly from the start (see `backend/Dockerfile`), you already satisfied this milestone's requirements while doing Milestone 0. Today is about **verifying** each requirement explicitly and understanding *why* each line is there, not writing new Dockerfile content.

## Walk through the Dockerfile line by line

Open `backend/Dockerfile` and check off each requirement against the actual lines:

| Checklist item | Where it's satisfied |
|---|---|
| 1. Multi-stage build | `FROM maven:3.9-eclipse-temurin-21 AS build` (stage 1) then a second, separate `FROM eclipse-temurin:21-jre-alpine` (stage 2) — only stage 2 ships. |
| 2. Non-root user | `RUN addgroup -S ticketdesk && adduser -S ticketdesk -G ticketdesk` then `USER ticketdesk` before `ENTRYPOINT`. |
| 3. No build tools in final image | Stage 2's base image (`eclipse-temurin:21-jre-alpine`) contains a JRE only, no `javac`, no Maven — and `COPY --from=build` only copies the built jar, not the build stage's filesystem. |
| 4. Tagged with git commit SHA | Not in the Dockerfile itself — it's how you tag at push time: `docker tag ... :$(git rev-parse --short HEAD)`. |
| 5. Image scanning on ECR | Enabled on the repository itself (you turned this on in Milestone 0, step 1). |

## Confirm it for real

```bash
cd ticketdesk/backend
SHA=$(git rev-parse --short HEAD)
docker build -t tkt-<initials>-api:$SHA .

# non-root check
docker run --rm tkt-<initials>-api:$SHA whoami
# -> ticketdesk

# no shell build tools present
docker run --rm tkt-<initials>-api:$SHA which mvn javac
# -> both should fail / return nothing, confirming they're absent

# image size sanity check
docker images tkt-<initials>-api:$SHA
```

Push the freshly tagged image and check the ECR console — under the repository, the **Scan status** column should show a completed vulnerability scan a few minutes after push. Read it; fix anything HIGH/CRITICAL that's cheap to fix (usually a base image bump), note anything else in your report rather than silently ignoring it.

**Done when:** image is in ECR with a traceable SHA tag, `docker run` works locally, scan has completed, and you can explain to a facilitator what each Dockerfile line does and what breaks if you remove it (this is exactly the kind of question demo day asks).

Next: [04 — Milestone 2: infrastructure as code](./04-milestone-2-infrastructure-as-code.md)
