#!/bin/bash

# LinkedIn AI Platform Database Restore Script
# This script restores the database from a backup file

set -e

# Check if backup file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file>"
    echo "Example: $0 /backups/backup_20231201_120000.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"
DB_NAME="linkedin_ai_prod"
DB_USER="linkedin_ai"

# Verify backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file $BACKUP_FILE not found"
    exit 1
fi

echo "WARNING: This will completely replace the current database!"
echo "Backup file: $BACKUP_FILE"
echo "Database: $DB_NAME"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

echo "Starting database restore at $(date)"

# Stop the web application
echo "Stopping web application..."
docker-compose -f docker-compose.prod.yml stop web worker

# Drop existing connections
echo "Terminating existing database connections..."
docker-compose -f docker-compose.prod.yml exec db psql -U $DB_USER -d postgres -c "
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = '$DB_NAME' AND pid <> pg_backend_pid();"

# Drop and recreate database
echo "Recreating database..."
docker-compose -f docker-compose.prod.yml exec db psql -U $DB_USER -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
docker-compose -f docker-compose.prod.yml exec db psql -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;"

# Restore from backup
echo "Restoring from backup..."
if [[ "$BACKUP_FILE" == *.gz ]]; then
    gunzip -c "$BACKUP_FILE" | docker-compose -f docker-compose.prod.yml exec -T db psql -U $DB_USER -d $DB_NAME
else
    cat "$BACKUP_FILE" | docker-compose -f docker-compose.prod.yml exec -T db psql -U $DB_USER -d $DB_NAME
fi

if [ $? -eq 0 ]; then
    echo "Database restore completed successfully"
    
    # Start the web application
    echo "Starting web application..."
    docker-compose -f docker-compose.prod.yml start web worker
    
    echo "Restore completed at $(date)"
else
    echo "Database restore failed!"
    
    # Try to start the application anyway
    docker-compose -f docker-compose.prod.yml start web worker
    exit 1
fi