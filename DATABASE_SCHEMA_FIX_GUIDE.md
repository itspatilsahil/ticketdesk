# Database Schema Fix - Missing s3key Column

**Status**: 🔴 CRITICAL - Database Schema Mismatch  
**Root Cause**: The `attachments` table is missing the `s3key` column  
**Impact**: Application fails to start, all ECS tasks crash  
**Fix Time**: 5-10 minutes  

## Problem Explanation

The application startup logs show this error:

```
ERROR: Schema-validation: missing column [s3key] in table [attachments]
```

### What's Happening

1. ✅ ECS task starts successfully
2. ✅ Docker container initializes
3. ✅ Spring Boot application begins startup
4. ✅ Database connection established successfully
5. ✅ Tomcat web server starts on port 8080
6. ❌ **Hibernate schema validation fails**
   - Application expects `s3key` column in `attachments` table
   - Column doesn't exist in database
   - JPA EntityManagerFactory initialization fails
   - Application crashes before responding to health checks

### Why It Crashes

The Java application has a JPA entity mapped to the `attachments` table:

```java
@Entity
@Table(name = "attachments")
public class Attachment {
    @Column(name = "s3key")
    private String s3key;  // ← This column is missing!
    // ... other fields
}
```

When Spring Boot starts, it validates the database schema against the entity definitions. The validation fails because the column doesn't exist.

## Solution: Add the Missing Column

### Option 1: Automatic Fix (Recommended)

#### Prerequisites
- PostgreSQL client (`psql`) installed on your machine
- AWS CLI configured with credentials
- Access to RDS database

#### Step 1: Navigate to the ticketdesk-complete folder

```bash
cd ~/Downloads/ticketdesk-complete
```

#### Step 2: Run the automatic fix script

```bash
chmod +x RUN_DATABASE_FIX.sh
./RUN_DATABASE_FIX.sh
```

This script will:
1. Retrieve database credentials from AWS SSM Parameter Store and Secrets Manager
2. Connect to your RDS database
3. Execute the SQL migration to add the `s3key` column
4. Display the updated table schema

#### Expected Output

```
==================================================
TicketDesk Database Schema Fix
==================================================

Database Configuration:
  Host: tkt-sp-rds.xxxxxxxxxx.ap-south-1.rds.amazonaws.com
  Port: 5432
  Database: ticketdesk
  User: admin

Executing schema fix...

Successfully added s3key column to attachments table
 column_name  | data_type | is_nullable
--------------+-----------+-------------
 id           | bigint    | f
 file_name    | character | t
 content_type | character | t
 file_size    | bigint    | t
 created_at   | timestamp | t
 s3key        | character | t

==================================================
✓ Database schema fixed successfully!
==================================================
```

### Option 2: Manual Fix (If psql is not installed)

#### Using AWS RDS Query Editor

1. Go to AWS Console → RDS → Databases
2. Select your database instance `tkt-sp-rds`
3. Click **Query Editor** (or **Database Activity Stream**)
4. Open the SQL editor
5. Copy and paste the SQL from `FIX_DATABASE_SCHEMA.sql`:

```sql
ALTER TABLE attachments
ADD COLUMN s3key VARCHAR(255);
```

6. Execute the query
7. Verify the column was added

#### Using AWS Systems Manager Session Manager

If you have access to an EC2 instance or jumphost:

```bash
psql -h <RDS-ENDPOINT> -U admin -d ticketdesk << 'EOF'
ALTER TABLE attachments
ADD COLUMN s3key VARCHAR(255);
EOF
```

## Step 3: Force ECS Service to Deploy New Tasks

After adding the column, the application still needs to restart. Run:

```bash
aws ecs update-service \
  --cluster tkt-sp-cluster \
  --service tkt-sp-svc \
  --force-new-deployment \
  --region ap-south-1
```

## Step 4: Monitor the Deployment

```bash
aws ecs describe-services \
  --cluster tkt-sp-cluster \
  --services tkt-sp-svc \
  --region ap-south-1 \
  --query 'services[0].[runningCount, desiredCount]'
```

Expected output after 2-3 minutes:
```
[1, 1]  ← 1 running, 1 desired
```

## Step 5: Verify the Fix

### Check Health Endpoint

```bash
ALB_DNS=$(aws elbv2 describe-load-balancers --names tkt-sp-alb \
  --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text)

curl http://$ALB_DNS/health
```

Expected response:
```json
{
  "status": "UP",
  "timestamp": "2026-08-26T01:55:00Z"
}
```

### Check Application Logs

```bash
aws logs tail /ecs/tkt-sp-api --region ap-south-1 --since 5m
```

Should show:
```
INFO: TomcatWebServer: Tomcat started on port(s): 8080 (http)
INFO: TicketDeskApplication: Started TicketDeskApplication
```

No error messages about schema validation.

## Files Included

- **`FIX_DATABASE_SCHEMA.sql`** - SQL migration script
- **`RUN_DATABASE_FIX.sh`** - Automated bash script to execute the migration

## What Gets Added

The `s3key` column stores the AWS S3 object key for each attachment:

```sql
ALTER TABLE attachments
ADD COLUMN s3key VARCHAR(255);
```

This allows the application to:
- Store S3 object keys for uploaded files
- Retrieve files from S3 by their keys
- Track which S3 objects are associated with which attachments

## Troubleshooting

### Error: "psql: command not found"

Install PostgreSQL client:
```bash
# macOS
brew install postgresql

# Ubuntu/Debian
sudo apt-get install postgresql-client

# Windows (Git Bash)
# Download from https://www.postgresql.org/download/windows/
# Or use Windows Subsystem for Linux (WSL)
```

### Error: "could not translate host name"

The database host can't be resolved. Check:
1. Security group allows outbound to RDS
2. Database endpoint is correct
3. Network connectivity to RDS

### Error: "permission denied"

The database user doesn't have permission to alter the table. Ensure:
1. User has `ALTER TABLE` permission
2. The parameter store values are correct
3. The secrets manager secret is accessible

### Still Not Working?

Check the service events:

```bash
aws ecs describe-services \
  --cluster tkt-sp-cluster \
  --services tkt-sp-svc \
  --region ap-south-1 \
  --query 'services[0].events[:5]'
```

Check task logs:

```bash
aws logs tail /ecs/tkt-sp-api --region ap-south-1 --since 10m --follow
```

## After the Fix: M8 Completion

Once the database is fixed and the API is responding:

1. **Load Testing** (15 min) - Run `hey` tool with various load levels
2. **Metrics Collection** (10 min) - Gather CloudWatch metrics
3. **Cost Analysis** (15 min) - Analyze AWS costs
4. **Documentation** (10 min) - Complete M8 reports

See `M8_EXECUTION_CHECKLIST.md` for detailed steps.

---

**Next Action**: Run `RUN_DATABASE_FIX.sh` to add the missing column
