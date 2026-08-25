# 06 — Milestone 4: Frontend (Day 5)

## 1. Add the Terraform

```bash
cd ticketdesk/infra
cp milestones/m4-frontend/frontend.tf .
terraform plan
```

You should see ~6 new resources: the S3 bucket + its public-access-block + encryption config + bucket policy, the CloudFront Origin Access Control, and the CloudFront distribution itself.

```bash
terraform apply
```

CloudFront distributions take **10-15 minutes** to deploy globally the first time — this is normal, not a hang. Get a coffee.

## 2. Upload the frontend

```bash
aws s3 sync ../frontend/ s3://$(terraform output -raw frontend_bucket)/ --region ap-south-1
```

There's no build step — `frontend/index.html` is the whole thing, plain HTML/CSS/JS, deliberately no framework and no bundler. That's the "keep it small" instruction applied to the frontend, not just the backend.

## 3. Verify end to end

```bash
terraform output cloudfront_url
```

Open that URL in a browser. You should see the TicketDesk UI, be able to create a ticket, see it appear in the table, and change its status from the dropdown — all through CloudFront, none of it talking to the ALB URL directly.

Confirm the S3 bucket really isn't public:

```bash
aws s3api get-public-access-block --bucket $(terraform output -raw frontend_bucket) --region ap-south-1
# every field should be "true"

curl -sI https://$(terraform output -raw frontend_bucket).s3.ap-south-1.amazonaws.com/index.html
# should NOT return 200 - direct bucket access must fail
```

**Done when:** the CloudFront URL loads the full app and works end to end, and direct S3 access is refused.

Next: [07 — Milestone 5: serverless attachments](./07-milestone-5-serverless-attachments.md)
