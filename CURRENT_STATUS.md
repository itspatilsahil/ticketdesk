# TicketDesk Deployment - Current Status

**Date**: August 25, 2026  
**Status**: 🔴 **INVESTIGATING** - Health Checks Failing  
**Last Update**: After IAM permission fix and grace period increase

## Problem Summary

The ECS deployment is experiencing repeated health check failures. While the task shows `RUNNING` status, the ALB health checks are failing (503 Service Temporarily Unavailable).

### Current Symptoms
- ✅ Task is in RUNNING state
- ❌ ALB health checks failing (503 errors)
- ❌ Service targets in "draining" state
- ❌ Repeated cycle: register → check → fail → drain → stop

### What We've Already Fixed

1. **Port Configuration** ✅
   - Changed container port from 3000 → 8080 (Java default)
   - Corrected ALB target group to port 8080

2. **AWS Region Environment Variable** ✅
   - Added AWS_REGION=ap-south-1 to task definition
   - Required for AWS SDK initialization

3. **IAM Task Role Permissions** ✅
   - Added Secrets Manager access (rds!db-*)
   - Added SSM Parameter Store access (parameter/tkt-sp/db/*)

4. **Health Check Grace Period** ✅
   - Increased from 60 → 180 seconds
   - Allows Java/Spring Boot startup time

## Next Diagnostic Step

The most important step is to **check the application logs** to understand why health checks are failing despite the task running.

### What to Do Now

1. **On your machine** (where AWS CLI is configured):
   ```bash
   cd ~/Downloads/ticketdesk
   chmod +x GET_LOGS.sh
   ./GET_LOGS.sh
   ```

2. **Look for error messages** such as:
   - `UnsatisfiedDependencyException` → Missing Bean configuration
   - `Unable to load region` → AWS_REGION not set properly
   - `Connection refused` → Database unreachable
   - `Connection timeout` → Network issues
   - `SocketTimeoutException` → Slow/hung connection
   - `ERROR` or `Exception` → Application errors

3. **If you see errors**, run the comprehensive diagnostic:
   ```bash
   chmod +x DIAGNOSE_HEALTH_CHECK.sh
   ./DIAGNOSE_HEALTH_CHECK.sh
   ```

## Probable Root Causes (In Order of Likelihood)

1. **Database Connection Hanging** (40% likely)
   - Application tries to connect to RDS on startup
   - Connection is timing out or blocked
   - Health check times out before returning

2. **Missing/Invalid Database Credentials** (30% likely)
   - DB_HOST, DB_PORT, DB_NAME, DB_USERNAME from SSM Parameter Store
   - DB_PASSWORD from Secrets Manager
   - Invalid credentials cause startup failure

3. **Application Startup Exception** (20% likely)
   - Spring Boot unable to initialize
   - Missing dependency or configuration error
   - Bean creation failure

4. **Network/Security Group Issue** (10% likely)
   - Task unable to reach RDS
   - Task unable to reach AWS services (SSM, Secrets Manager)

## Files Available

- **`GET_LOGS.sh`** - Quick script to fetch latest logs
- **`DIAGNOSE_HEALTH_CHECK.sh`** - Comprehensive diagnostic with all service details
- **`QUICK_FIX_COMMAND.sh`** - Re-run if task definition needs update
- **`FIX_DEPLOYMENT.sh`** - Comprehensive fix with full verification

## What Each Fix Script Does

### QUICK_FIX_COMMAND.sh (2-3 min)
- Fetches current task definition from ECS
- Ensures AWS_REGION=ap-south-1 is set
- Registers new task definition revision
- Updates service with new revision
- Waits for running tasks
- Tests health endpoint with curl

### FIX_DEPLOYMENT.sh (3-5 min)
- Same as QUICK_FIX but with more detailed verification
- Checks current deployments
- Verifies all environment variables
- Monitors service events
- Provides more detailed status output

## After Logging Issue

Once we understand the root cause from the logs, the fix path is:

1. **If database connection issue**: 
   - Verify RDS is running and accepting connections
   - Check security groups allow ECS → RDS traffic
   - Verify database credentials are correct

2. **If credentials issue**:
   - Verify parameters exist in SSM Parameter Store
   - Verify secrets exist in Secrets Manager
   - Verify IAM policy grants read access

3. **If startup exception**:
   - Review full stack trace from logs
   - May need application code changes

## M8 Completion Timeline

Once deployment is fixed:
- **Phase 1: Verify** (5 min) - Confirm API responding
- **Phase 2: Load Testing** (15 min) - Run hey tool tests
- **Phase 3: Metrics** (10 min) - Collect CloudWatch metrics
- **Phase 4: Cost Analysis** (15 min) - Analyze costs
- **Phase 5: Documentation** (10 min) - Finalize reports

**Total to M8 completion**: ~60 minutes after deployment fixed

## Quick Reference Commands

```bash
# Get ALB DNS
aws elbv2 describe-load-balancers --names tkt-sp-alb \
  --region ap-south-1 --query 'LoadBalancers[0].DNSName' --output text

# Test health endpoint  
curl http://<ALB_DNS>/health

# Check task status
aws ecs describe-services --cluster tkt-sp-cluster --services tkt-sp-svc \
  --region ap-south-1 --query 'services[0].[runningCount, desiredCount]'

# View logs
aws logs tail /ecs/tkt-sp-api --region ap-south-1 --follow

# Check target health
aws elbv2 describe-target-health --target-group-arn <TG_ARN> --region ap-south-1
```

---

**ACTION REQUIRED**: Run `GET_LOGS.sh` on your machine to diagnose the specific failure cause.
