#!/bin/bash

# LinkedIn AI Platform Database Backup Script
# This script creates automated backups of the production database

set -e

# Configuration
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="linkedin_ai_prod"
DB_USER="linkedin_ai"
RETENTION_DAYS=30
S3_BUCKET="${AWS_S3_BACKUP_BUCKET:-linkedin-ai-backups}"

# Ensure backup directory exists
mkdir -p $BACKUP_DIR

# Create local backup
echo "Starting database backup at $(date)"
docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U $DB_USER $DB_NAME | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

if [ $? -eq 0 ]; then
    echo "Local backup completed: backup_$DATE.sql.gz"
    
    # Upload to S3 if configured
    if [ ! -z "$AWS_ACCESS_KEY_ID" ] && [ ! -z "$S3_BUCKET" ]; then
        echo "Uploading backup to S3..."
        aws s3 cp $BACKUP_DIR/backup_$DATE.sql.gz s3://$S3_BUCKET/database/backup_$DATE.sql.gz
        
        if [ $? -eq 0 ]; then
            echo "S3 upload completed"
        else
            echo "S3 upload failed"
        fi
    fi
    
    # Clean up old local backups
    find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete
    echo "Cleaned up backups older than $RETENTION_DAYS days"
    
    # Log backup completion
    echo "Backup completed successfully at $(date)"
    
else
    echo "Backup failed!"
    exit 1
fi