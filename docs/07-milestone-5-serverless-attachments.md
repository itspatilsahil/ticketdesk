# 07 — Milestone 5: your first serverless piece (Day 6)

Three things happen today: the API gains presigned-upload endpoints, a Lambda function starts existing, and S3 is wired to call it automatically. End of today is also your **individual sign-off demo** — budget time for that.

## 1. Bring in the staged backend code

```bash
cd ticketdesk/backend
cp -r milestones/m5-serverless-attachments/src/main/java/com/ticketdesk/api/config src/main/java/com/ticketdesk/api/
cp -r milestones/m5-serverless-attachments/src/main/java/com/ticketdesk/api/controller/AttachmentController.java src/main/java/com/ticketdesk/api/controller/
cp -r milestones/m5-serverless-attachments/src/main/java/com/ticketdesk/api/dto/*.java src/main/java/com/ticketdesk/api/dto/
```

Open `pom.xml` and `src/main/resources/application-prod.yml`, then apply the two small additions described in `milestones/m5-serverless-attachments/pom-additions.xml` and `.../application-prod-additions.yml`. These are deliberately manual, one-line-ish edits rather than another `cp` — look at what you're adding.

Read `AttachmentController.java` before moving on. Understand the `presign` → browser-uploads-directly → `confirm` flow, and why `thumbnailKeyFor()` just does string substitution instead of querying a database.

## 2. Build and push a new image

```bash
mvn clean package
SHA=$(git rev-parse --short HEAD)
docker build -t tkt-<initials>-api:$SHA .
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com
docker tag tkt-<initials>-api:$SHA <account-id>.dkr.ecr.ap-south-1.amazonaws.com/tkt-<initials>-api:$SHA
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/tkt-<initials>-api:$SHA
```

Update `container_image` in `infra/terraform.tfvars` to the new tag.

## 3. Build the Lambda package

```bash
cd ../lambda-thumbnail
chmod +x build.sh
./build.sh
```

This installs Pillow for Lambda's actual runtime platform (not your laptop's), not just your local OS — read `build.sh`'s comment on why `--platform manylinux2014_x86_64` matters; skipping it is the single most common reason a "it worked on my machine" Lambda fails in AWS with an import error.

## 4. Add the Terraform

```bash
cd ../infra
cp milestones/m5-serverless-attachments/attachments.tf .
diff ecs.tf milestones/m5-serverless-attachments/ecs.tf
cp milestones/m5-serverless-attachments/ecs.tf .

terraform plan
terraform apply
```

## 5. Verify — end to end, without your API ever touching file bytes

```bash
ALB=$(terraform output -raw alb_dns_name)
CF=$(terraform output -raw cloudfront_url)

# create a ticket, note its id
TICKET_ID=$(curl -s -X POST $CF/api/tickets -H "Content-Type: application/json" \
  -d '{"title":"Screenshot attached","category":"SOFTWARE","priority":"LOW"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# ask the API for a presigned upload URL
RESP=$(curl -s -X POST $CF/api/tickets/$TICKET_ID/attachments/presign \
  -H "Content-Type: application/json" -d '{"filename":"screenshot.png","contentType":"image/png"}')
echo $RESP

UPLOAD_URL=$(echo $RESP | python3 -c "import sys,json; print(json.load(sys.stdin)['uploadUrl'])")
S3_KEY=$(echo $RESP | python3 -c "import sys,json; print(json.load(sys.stdin)['s3Key'])")

# the browser's move: PUT the actual file bytes straight to S3 - your API is not in this request
curl -s -X PUT "$UPLOAD_URL" -H "Content-Type: image/png" --data-binary @/path/to/any/screenshot.png

# tell the API the upload finished
curl -s -X POST $CF/api/tickets/$TICKET_ID/attachments \
  -H "Content-Type: application/json" -d "{\"filename\":\"screenshot.png\",\"s3Key\":\"$S3_KEY\"}"

# wait ~10 seconds for the Lambda to run, then check
aws s3 ls s3://$(terraform output -raw attachments_bucket)/thumbnails/$TICKET_ID/ --region ap-south-1
```

**Done when:** a thumbnail object shows up under `thumbnails/<ticket-id>/` a few seconds after the upload, and `GET $CF/api/tickets/$TICKET_ID/attachments` returns a `thumbnailUrl` that actually loads an image in a browser. Also check CloudWatch → Log groups → `/aws/lambda/tkt-<initials>-thumbnail` to see the Lambda's own execution log — this is what "read the logs" means in practice.

## 6. End of Day 6: individual sign-off

Before your 10-minute demo, run back through Milestones 0-5 once more end to end (`terraform destroy` then `terraform apply` if you have time — it's the best possible warm-up for M8, and doing it now instead of Day 9 means you find out today if something quietly depends on manual state).

Next: [08 — Milestone 6: CI/CD pipeline](./08-milestone-6-cicd-pipeline.md)
