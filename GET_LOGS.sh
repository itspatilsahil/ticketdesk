#!/bin/bash
# Simple script to fetch and display recent CloudWatch logs
# Run this on your machine with AWS CLI configured

REGION="ap-south-1"
LOG_GROUP="/ecs/tkt-sp-api"

echo "Fetching latest logs from $LOG_GROUP..."
echo ""

# Get the most recent log events
aws logs tail $LOG_GROUP \
  --region $REGION \
  --since 30m

echo ""
echo "Done. If logs show errors, check for:"
echo "  • UnsatisfiedDependencyException"
echo "  • Unable to load region"
echo "  • Connection refused"
echo "  • Connection timeout"
echo "  • Any ERROR or Exception stack traces"
