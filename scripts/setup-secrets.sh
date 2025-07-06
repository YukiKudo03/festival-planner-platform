#!/bin/bash

# Secrets Setup Script for Festival Planner Platform
# This script helps generate and manage production secrets

set -e

# Configuration
SECRETS_DIR="secrets"
RAILS_SECRET_LENGTH=128
POSTGRES_PASSWORD_LENGTH=32

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if OpenSSL is installed
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        error "OpenSSL is not installed. Please install OpenSSL first."
        exit 1
    fi
}

# Create secrets directory
create_secrets_dir() {
    if [ ! -d "$SECRETS_DIR" ]; then
        log "Creating secrets directory: $SECRETS_DIR"
        mkdir -p "$SECRETS_DIR"
        chmod 700 "$SECRETS_DIR"
    fi
}

# Generate random password
generate_password() {
    local length="${1:-32}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Generate Rails secret key base
generate_rails_secret() {
    log "Generating Rails SECRET_KEY_BASE..."
    local secret_file="$SECRETS_DIR/secret_key_base.txt"
    
    if [ -f "$secret_file" ]; then
        warning "Rails secret key already exists. Use --force to overwrite."
        return 0
    fi
    
    openssl rand -hex "$RAILS_SECRET_LENGTH" > "$secret_file"
    chmod 600 "$secret_file"
    log "Rails secret key generated: $secret_file"
}

# Generate PostgreSQL password
generate_postgres_password() {
    log "Generating PostgreSQL password..."
    local password_file="$SECRETS_DIR/postgres_password.txt"
    
    if [ -f "$password_file" ]; then
        warning "PostgreSQL password already exists. Use --force to overwrite."
        return 0
    fi
    
    generate_password "$POSTGRES_PASSWORD_LENGTH" > "$password_file"
    chmod 600 "$password_file"
    log "PostgreSQL password generated: $password_file"
}

# Copy Rails master key
copy_rails_master_key() {
    log "Setting up Rails master key..."
    local master_key_source="config/master.key"
    local master_key_target="$SECRETS_DIR/rails_master_key.txt"
    
    if [ ! -f "$master_key_source" ]; then
        log "Generating new Rails master key..."
        bundle exec rails credentials:edit --editor=true || true
    fi
    
    if [ -f "$master_key_source" ]; then
        cp "$master_key_source" "$master_key_target"
        chmod 600 "$master_key_target"
        log "Rails master key copied: $master_key_target"
    else
        error "Rails master key not found. Please run 'rails credentials:edit' first."
        exit 1
    fi
}

# Generate Redis password
generate_redis_password() {
    log "Generating Redis password..."
    local password_file="$SECRETS_DIR/redis_password.txt"
    
    if [ -f "$password_file" ]; then
        warning "Redis password already exists. Use --force to overwrite."
        return 0
    fi
    
    generate_password 32 > "$password_file"
    chmod 600 "$password_file"
    log "Redis password generated: $password_file"
}

# Generate JWT secret
generate_jwt_secret() {
    log "Generating JWT secret..."
    local secret_file="$SECRETS_DIR/jwt_secret.txt"
    
    if [ -f "$secret_file" ]; then
        warning "JWT secret already exists. Use --force to overwrite."
        return 0
    fi
    
    openssl rand -hex 64 > "$secret_file"
    chmod 600 "$secret_file"
    log "JWT secret generated: $secret_file"
}

# Generate health check token
generate_health_check_token() {
    log "Generating health check token..."
    local token_file="$SECRETS_DIR/health_check_token.txt"
    
    if [ -f "$token_file" ]; then
        warning "Health check token already exists. Use --force to overwrite."
        return 0
    fi
    
    generate_password 32 > "$token_file"
    chmod 600 "$token_file"
    log "Health check token generated: $token_file"
}

# Create environment file template with secrets
create_env_template() {
    log "Creating environment template with generated secrets..."
    local env_file=".env.production"
    
    if [ -f "$env_file" ] && [ "$FORCE" != "true" ]; then
        warning "Environment file already exists. Use --force to overwrite."
        return 0
    fi
    
    # Copy from template if it exists
    if [ -f ".env.production.example" ]; then
        cp ".env.production.example" "$env_file"
    else
        error "Environment template not found: .env.production.example"
        return 1
    fi
    
    # Update Redis password in env file
    if [ -f "$SECRETS_DIR/redis_password.txt" ]; then
        local redis_password
        redis_password=$(cat "$SECRETS_DIR/redis_password.txt")
        sed -i.bak "s/your_redis_password_here/$redis_password/g" "$env_file"
        rm -f "${env_file}.bak"
    fi
    
    # Update health check token
    if [ -f "$SECRETS_DIR/health_check_token.txt" ]; then
        local health_token
        health_token=$(cat "$SECRETS_DIR/health_check_token.txt")
        sed -i.bak "s/your_health_check_token_here/$health_token/g" "$env_file"
        rm -f "${env_file}.bak"
    fi
    
    chmod 600 "$env_file"
    log "Environment file created: $env_file"
    warning "Remember to update other configuration values in $env_file"
}

# Validate all secrets exist
validate_secrets() {
    log "Validating secrets..."
    local missing_secrets=()
    
    local required_secrets=(
        "secret_key_base.txt"
        "postgres_password.txt"
        "rails_master_key.txt"
    )
    
    for secret in "${required_secrets[@]}"; do
        if [ ! -f "$SECRETS_DIR/$secret" ]; then
            missing_secrets+=("$secret")
        fi
    done
    
    if [ ${#missing_secrets[@]} -eq 0 ]; then
        log "All required secrets are present!"
        return 0
    else
        error "Missing secrets: ${missing_secrets[*]}"
        return 1
    fi
}

# Show secrets status
show_status() {
    log "Secrets status:"
    
    local secrets=(
        "secret_key_base.txt:Rails Secret Key Base"
        "postgres_password.txt:PostgreSQL Password"
        "rails_master_key.txt:Rails Master Key"
        "redis_password.txt:Redis Password"
        "jwt_secret.txt:JWT Secret"
        "health_check_token.txt:Health Check Token"
    )
    
    for secret_info in "${secrets[@]}"; do
        IFS=':' read -r file description <<< "$secret_info"
        if [ -f "$SECRETS_DIR/$file" ]; then
            echo "  ✓ $description ($file)"
        else
            echo "  ✗ $description ($file) - Missing"
        fi
    done
}

# Backup secrets
backup_secrets() {
    log "Creating secrets backup..."
    local backup_file="secrets_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if [ -d "$SECRETS_DIR" ]; then
        tar -czf "$backup_file" "$SECRETS_DIR"
        chmod 600 "$backup_file"
        log "Secrets backup created: $backup_file"
        warning "Store this backup securely and delete it from this server after copying!"
    else
        error "Secrets directory not found!"
        return 1
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [options] [command]"
    echo ""
    echo "Commands:"
    echo "  generate     - Generate all secrets (default)"
    echo "  rails        - Generate Rails secrets only"
    echo "  postgres     - Generate PostgreSQL password only"
    echo "  redis        - Generate Redis password only"
    echo "  jwt          - Generate JWT secret only"
    echo "  health       - Generate health check token only"
    echo "  validate     - Validate all secrets exist"
    echo "  status       - Show secrets status"
    echo "  backup       - Create secrets backup"
    echo "  env          - Create environment file with secrets"
    echo ""
    echo "Options:"
    echo "  --force      - Overwrite existing secrets"
    echo "  --help       - Show this help message"
}

# Main function
main() {
    local command="${1:-generate}"
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                command="$1"
                shift
                ;;
        esac
    done
    
    log "Festival Planner Platform - Secrets Setup"
    log "Command: $command"
    
    # Pre-checks
    check_openssl
    create_secrets_dir
    
    case "$command" in
        "generate")
            generate_rails_secret
            generate_postgres_password
            copy_rails_master_key
            generate_redis_password
            generate_jwt_secret
            generate_health_check_token
            create_env_template
            ;;
        "rails")
            generate_rails_secret
            copy_rails_master_key
            ;;
        "postgres")
            generate_postgres_password
            ;;
        "redis")
            generate_redis_password
            ;;
        "jwt")
            generate_jwt_secret
            ;;
        "health")
            generate_health_check_token
            ;;
        "validate")
            validate_secrets
            ;;
        "status")
            show_status
            ;;
        "backup")
            backup_secrets
            ;;
        "env")
            create_env_template
            ;;
        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
    
    log "Secrets setup completed!"
    
    if [ "$command" = "generate" ]; then
        echo ""
        warning "IMPORTANT SECURITY NOTES:"
        warning "1. Keep these secrets secure and never commit them to version control"
        warning "2. Back up secrets securely before deploying to production"
        warning "3. Rotate secrets regularly in production"
        warning "4. Ensure proper file permissions (600) are maintained"
        warning "5. Update .env.production with your actual API keys and configuration"
    fi
}

# Run main function
main "$@"