#!/bin/bash
# Comprehensive diagnostic script for health check failures
# Run this on your machine with AWS CLI configured

REGION="ap-south-1"
CLUSTER_NAME="tkt-sp-cluster"
SERVICE_NAME="tkt-sp-svc"
LOG_GROUP="/ecs/tkt-sp-api"

echo "=========================================="
echo "TicketDesk Health Check Diagnostics"
echo "=========================================="
echo ""

# Step 1: Get service status
echo "1. ECS Service Status:"
echo "---"
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $REGION \
  --query 'services[0].[runningCount, desiredCount, taskDefinition, deployments]' \
  --output json | head -20

echo ""
echo "2. Recent Service Events (last 10):"
echo "---"
aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --region $REGION \
  --query 'services[0].events[:10].[createdAt, message]' \
  --output text

echo ""
echo "3. Task Definition Environment Variables:"
echo "---"
aws ecs describe-task-definition \
  --task-definition tkt-sp-api-task \
  --region $REGION \
  --query 'taskDefinition.containerDefinitions[0].environment' \
  --output table

echo ""
echo "4. Latest Task Details:"
echo "---"
LATEST_TASK=$(aws ecs list-tasks \
  --cluster $CLUSTER_NAME \
  --service-name $SERVICE_NAME \
  --region $REGION \
  --query 'taskArns[0]' \
  --output text)

if [ ! -z "$LATEST_TASK" ] && [ "$LATEST_TASK" != "None" ]; then
  echo "Task ARN: $LATEST_TASK"
  echo ""

  aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $LATEST_TASK \
    --region $REGION \
    --query 'tasks[0].[lastStatus, taskStatus, stoppedCode, stoppedReason, startedAt, createdAt]' \
    --output json

  echo ""
  echo "5. Task Container Status:"
  echo "---"
  aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $LATEST_TASK \
    --region $REGION \
    --query 'tasks[0].containers[0].[lastStatus, exitCode, reason]' \
    --output json

  echo ""
  echo "6. ALB Target Health:"
  echo "---"
  TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
    --region $REGION \
    --query "TargetGroups[?TargetGroupName=='tkt-sp-tg'].TargetGroupArn" \
    --output text)

  if [ ! -z "$TARGET_GROUP_ARN" ] && [ "$TARGET_GROUP_ARN" != "None" ]; then
    aws elbv2 describe-target-health \
      --target-group-arn $TARGET_GROUP_ARN \
      --region $REGION \
      --query 'TargetHealthDescriptions[*].[Target.Id, TargetHealth.State, TargetHealth.Reason, TargetHealth.Description]' \
      --output table
  fi
else
  echo "No tasks running"
fi

echo ""
echo "7. CloudWatch Logs (last 50 lines):"
echo "---"
aws logs tail $LOG_GROUP \
  --region $REGION \
  --max-items 50

echo ""
echo "8. Error Logs (ERROR, Exception):"
echo "---"
aws logs filter-log-events \
  --log-group-name $LOG_GROUP \
  --filter-pattern "ERROR" \
  --region $REGION \
  --query 'events[*].[timestamp, message]' \
  --output text | tail -20

echo ""
echo "=========================================="
echo "Diagnostic Summary:"
echo "=========================================="
echo ""
echo "Check for:"
echo "  • Service Status: Should show runningCount = desiredCount"
echo "  • Task Status: Should show lastStatus = RUNNING"
echo "  • Container Status: Should show lastStatus = RUNNING, exitCode = null"
echo "  • ALB Targets: Should show healthy (State = healthy)"
echo "  • Logs: Should have no ERROR or Exception messages"
echo ""
echo "Common issues:"
echo "  • Task status STOPPED: Check exitCode and reason"
echo "  • Task status RUNNING but ALB targets unhealthy: Check application logs"
echo "  • stoppedReason includes 'Essential container': Application crashed"
echo "  • Logs show 'Unable to load region': AWS_REGION not set"
echo "  • Logs show 'Cannot connect to RDS': Database unreachable or credentials invalid"
echo ""
