# 01 — Build and run TicketDesk locally (Day 0/1, before touching AWS)

Do this before Milestone 0. It proves the app itself works, so that if something breaks later you know it's the AWS wiring, not the code.

## 1. Build the jar

```bash
cd ticketdesk/backend
mvn clean package
```

This runs on the **default** Spring profile, which uses an in-memory H2 database — nothing to install, nothing to configure. You'll switch to real Postgres in Milestone 3.

## 2. Run it

```bash
java -jar target/ticketdesk-api.jar
```

You should see Spring Boot's startup banner and `Tomcat started on port 8080`.

## 3. Exercise every endpoint

In a second terminal:

```bash
# health check (this is what the ALB target group will call later)
curl -s localhost:8080/actuator/health

# create a ticket
curl -s -X POST localhost:8080/api/tickets \
  -H "Content-Type: application/json" \
  -d '{"title":"Laptop wont boot","description":"Black screen after login","category":"HARDWARE","priority":"HIGH"}'

# list tickets
curl -s localhost:8080/api/tickets

# filter
curl -s "localhost:8080/api/tickets?status=OPEN&priority=HIGH"

# update status (replace 1 with the id returned above)
curl -s -X PATCH localhost:8080/api/tickets/1/status \
  -H "Content-Type: application/json" -d '{"status":"IN_PROGRESS"}'

# add a comment
curl -s -X POST localhost:8080/api/tickets/1/comments \
  -H "Content-Type: application/json" -d '{"body":"Tried a hard reset, no change."}'

# dashboard counts
curl -s localhost:8080/api/tickets/dashboard
```

Every call should return JSON with no errors. Stop the app with Ctrl+C.

## 4. Build and run the container image

```bash
docker build -t ticketdesk-api:local .
docker run --rm -p 8080:8080 ticketdesk-api:local
```

Repeat the curl checks from step 3 against the same port — should behave identically, just running inside the container now.

Confirm it's non-root and lean while it's running:

```bash
docker exec $(docker ps -q --filter ancestor=ticketdesk-api:local) whoami
# -> ticketdesk (not root)

docker images ticketdesk-api:local
# check the size - should be well under 300MB
```

Stop the container with Ctrl+C.

**Done when:** all six endpoints return correct JSON both as a plain jar and as a container, and the container reports its user as `ticketdesk`, not `root`.

Next: [02 — Milestone 0: manual console deploy](./02-milestone-0-manual-console-deploy.md)
