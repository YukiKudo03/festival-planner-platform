#!/bin/bash

# Database backup script for Festival Planner Platform
# This script creates compressed backups of the PostgreSQL database

set -e

# Configuration
BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="festival_planner_platform_${TIMESTAMP}.sql.gz"
KEEP_BACKUPS=7  # Keep last 7 backups

# Database connection settings
DB_HOST="${POSTGRES_HOST:-postgres}"
DB_NAME="${POSTGRES_DB:-festival_planner_platform_production}"
DB_USER="${POSTGRES_USER:-postgres}"

# Ensure backup directory exists
mkdir -p "${BACKUP_DIR}"

# Create database backup
echo "Creating database backup: ${BACKUP_FILE}"
PGPASSWORD="$(cat /run/secrets/postgres_password)" pg_dump \
    -h "${DB_HOST}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --no-owner \
    --no-privileges \
    --format=plain \
    --compress=9 \
    | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

# Verify backup was created
if [ -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    echo "Backup created successfully: ${BACKUP_FILE}"
    echo "Size: $(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)"
else
    echo "ERROR: Backup file not found!"
    exit 1
fi

# Clean up old backups
echo "Cleaning up old backups (keeping last ${KEEP_BACKUPS})..."
cd "${BACKUP_DIR}"
ls -t festival_planner_platform_*.sql.gz | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f

# List remaining backups
echo "Remaining backups:"
ls -lah festival_planner_platform_*.sql.gz 2>/dev/null || echo "No backups found"

echo "Backup completed successfully!"