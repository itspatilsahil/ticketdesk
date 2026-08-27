#!/bin/bash
# Script to add missing s3key column to attachments table
# Requires: AWS CLI configured, psql installed, RDS password

REGION="ap-south-1"
DB_HOST=$(aws ssm get-parameter --name /tkt-sp/db/host --region $REGION --query 'Parameter.Value' --output text 2>/dev/null)
DB_PORT=$(aws ssm get-parameter --name /tkt-sp/db/port --region $REGION --query 'Parameter.Value' --output text 2>/dev/null || echo "5432")
DB_NAME=$(aws ssm get-parameter --name /tkt-sp/db/name --region $REGION --query 'Parameter.Value' --output text 2>/dev/null)
DB_USER=$(aws ssm get-parameter --name /tkt-sp/db/user --region $REGION --query 'Parameter.Value' --output text 2>/dev/null)
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id rds!db-password --region $REGION --query 'SecretString' --output text 2>/dev/null)

echo "=================================================="
echo "TicketDesk Database Schema Fix"
echo "=================================================="
echo ""
echo "Database Configuration:"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

if [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo "ERROR: Could not retrieve database credentials from SSM Parameter Store"
    echo ""
    echo "Make sure these parameters exist in SSM:"
    echo "  /tkt-sp/db/host"
    echo "  /tkt-sp/db/port"
    echo "  /tkt-sp/db/name"
    echo "  /tkt-sp/db/user"
    echo ""
    echo "And this secret exists in Secrets Manager:"
    echo "  rds!db-password"
    exit 1
fi

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "ERROR: psql is not installed"
    echo "Install PostgreSQL client: sudo apt-get install postgresql-client"
    exit 1
fi

echo "Executing schema fix..."
echo ""

# Run the SQL script
PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -f FIX_DATABASE_SCHEMA.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "=================================================="
    echo "✓ Database schema fixed successfully!"
    echo "=================================================="
    echo ""
    echo "The s3key column has been added to the attachments table."
    echo ""
    echo "Next steps:"
    echo "  1. Force ECS service to deploy new tasks:"
    echo "     aws ecs update-service --cluster tkt-sp-cluster --service tkt-sp-svc --force-new-deployment --region ap-south-1"
    echo ""
    echo "  2. Monitor deployment:"
    echo "     aws ecs describe-services --cluster tkt-sp-cluster --services tkt-sp-svc --region ap-south-1"
    echo ""
    echo "  3. Check task status after ~2-3 minutes"
    echo ""
else
    echo ""
    echo "=================================================="
    echo "✗ Error executing database fix"
    echo "=================================================="
    exit 1
fi
