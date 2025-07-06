#!/bin/bash

# Deployment script for Festival Planner Platform
# This script handles the deployment process with zero-downtime

set -e

# Configuration
COMPOSE_FILE="docker-compose.yml"
PROJECT_NAME="festival-planner-platform"
BACKUP_BEFORE_DEPLOY=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if secrets exist
check_secrets() {
    log "Checking secrets..."
    
    if [ ! -f "secrets/postgres_password.txt" ]; then
        error "postgres_password.txt not found in secrets directory"
        exit 1
    fi
    
    if [ ! -f "secrets/secret_key_base.txt" ]; then
        error "secret_key_base.txt not found in secrets directory"
        exit 1
    fi
    
    if [ ! -f "secrets/rails_master_key.txt" ]; then
        error "rails_master_key.txt not found in secrets directory"
        exit 1
    fi
    
    log "All secrets found"
}

# Create backup before deployment
create_backup() {
    if [ "$BACKUP_BEFORE_DEPLOY" = true ]; then
        log "Creating backup before deployment..."
        docker-compose --profile backup run --rm backup /backup.sh
        log "Backup completed"
    else
        log "Skipping backup (disabled)"
    fi
}

# Pull latest images
pull_images() {
    log "Pulling latest images..."
    docker-compose pull
    log "Images pulled successfully"
}

# Build application image
build_app() {
    log "Building application image..."
    docker-compose build --no-cache app
    log "Application image built successfully"
}

# Run database migrations
run_migrations() {
    log "Running database migrations..."
    docker-compose run --rm app bundle exec rails db:migrate
    log "Database migrations completed"
}

# Deploy with zero downtime
deploy() {
    log "Starting deployment..."
    
    # Start new services
    docker-compose up -d --force-recreate --renew-anon-volumes
    
    # Wait for services to be healthy
    log "Waiting for services to be healthy..."
    sleep 30
    
    # Check if app is responding
    if ! docker-compose exec app curl -f http://localhost:3000/up > /dev/null 2>&1; then
        error "Application health check failed"
        exit 1
    fi
    
    log "Deployment completed successfully"
}

# Clean up old images and containers
cleanup() {
    log "Cleaning up old images and containers..."
    docker system prune -f
    docker image prune -f
    log "Cleanup completed"
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Check if all services are running
    if ! docker-compose ps | grep -q "Up"; then
        error "Some services are not running"
        exit 1
    fi
    
    # Check application health endpoint
    if ! curl -f http://localhost/up > /dev/null 2>&1; then
        error "Application health check failed"
        exit 1
    fi
    
    log "Health check passed"
}

# Main deployment process
main() {
    log "Starting deployment process for ${PROJECT_NAME}..."
    
    # Pre-deployment checks
    check_secrets
    
    # Create backup
    create_backup
    
    # Pull and build
    pull_images
    build_app
    
    # Database migrations
    run_migrations
    
    # Deploy
    deploy
    
    # Post-deployment checks
    health_check
    
    # Cleanup
    cleanup
    
    log "Deployment process completed successfully!"
}

# Run main function
main "$@"