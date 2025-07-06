#!/bin/bash

# SSL Certificate Generation Script for Festival Planner Platform
# This script helps generate SSL certificates for different environments

set -e

# Configuration
DOMAIN="${1:-festival-planner.example.com}"
CERT_DIR="nginx/ssl"
DAYS="${2:-365}"

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

# Create certificate directory
create_cert_dir() {
    if [ ! -d "$CERT_DIR" ]; then
        log "Creating certificate directory: $CERT_DIR"
        mkdir -p "$CERT_DIR"
    fi
}

# Generate self-signed certificate for development
generate_self_signed() {
    log "Generating self-signed certificate for domain: $DOMAIN"
    
    # Certificate details
    COUNTRY="JP"
    STATE="Tokyo"
    CITY="Tokyo"
    ORGANIZATION="Festival Planner Platform"
    
    # Generate private key
    log "Generating private key..."
    openssl genrsa -out "$CERT_DIR/$DOMAIN.key" 2048
    
    # Generate certificate
    log "Generating self-signed certificate..."
    openssl req -new -x509 -key "$CERT_DIR/$DOMAIN.key" -out "$CERT_DIR/$DOMAIN.crt" -days "$DAYS" -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/CN=$DOMAIN"
    
    # Set proper permissions
    chmod 644 "$CERT_DIR/$DOMAIN.crt"
    chmod 600 "$CERT_DIR/$DOMAIN.key"
    
    log "Self-signed certificate generated successfully!"
    warning "This is a self-signed certificate and should only be used for development."
    warning "Browsers will show security warnings for self-signed certificates."
}

# Generate CSR for production certificate
generate_csr() {
    log "Generating Certificate Signing Request (CSR) for domain: $DOMAIN"
    
    # Certificate details
    COUNTRY="JP"
    STATE="Tokyo"
    CITY="Tokyo"
    ORGANIZATION="Festival Planner Platform"
    EMAIL="${3:-admin@${DOMAIN}}"
    
    # Generate private key
    log "Generating private key..."
    openssl genrsa -out "$CERT_DIR/$DOMAIN.key" 2048
    
    # Generate CSR
    log "Generating CSR..."
    openssl req -new -key "$CERT_DIR/$DOMAIN.key" -out "$CERT_DIR/$DOMAIN.csr" -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/CN=$DOMAIN/emailAddress=$EMAIL"
    
    # Set proper permissions
    chmod 644 "$CERT_DIR/$DOMAIN.csr"
    chmod 600 "$CERT_DIR/$DOMAIN.key"
    
    log "CSR generated successfully!"
    log "CSR file: $CERT_DIR/$DOMAIN.csr"
    log "Private key: $CERT_DIR/$DOMAIN.key"
    log "Submit the CSR to your Certificate Authority to obtain the certificate."
}

# Generate Let's Encrypt certificate
generate_letsencrypt() {
    log "Setting up Let's Encrypt certificate for domain: $DOMAIN"
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        error "Certbot is not installed. Please install certbot first."
        echo "On Ubuntu/Debian: sudo apt-get install certbot"
        echo "On CentOS/RHEL: sudo yum install certbot"
        exit 1
    fi
    
    # Generate certificate
    log "Generating Let's Encrypt certificate..."
    warning "Make sure your domain points to this server and port 80 is accessible."
    
    if sudo certbot certonly --standalone -d "$DOMAIN" --agree-tos --no-eff-email; then
        # Copy certificates
        log "Copying certificates to application directory..."
        sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/$DOMAIN.crt"
        sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$CERT_DIR/$DOMAIN.key"
        
        # Set proper ownership and permissions
        sudo chown "$(whoami):$(whoami)" "$CERT_DIR/$DOMAIN.crt" "$CERT_DIR/$DOMAIN.key"
        chmod 644 "$CERT_DIR/$DOMAIN.crt"
        chmod 600 "$CERT_DIR/$DOMAIN.key"
        
        log "Let's Encrypt certificate installed successfully!"
        log "Certificate will expire in 90 days. Set up auto-renewal."
    else
        error "Failed to generate Let's Encrypt certificate."
        exit 1
    fi
}

# Validate certificate
validate_certificate() {
    if [ -f "$CERT_DIR/$DOMAIN.crt" ]; then
        log "Validating certificate..."
        
        # Check certificate details
        echo "Certificate details:"
        openssl x509 -in "$CERT_DIR/$DOMAIN.crt" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)"
        
        # Check if private key matches certificate
        cert_hash=$(openssl x509 -in "$CERT_DIR/$DOMAIN.crt" -pubkey -noout -outform PEM | sha256sum)
        key_hash=$(openssl rsa -in "$CERT_DIR/$DOMAIN.key" -pubout -outform PEM | sha256sum)
        
        if [ "$cert_hash" = "$key_hash" ]; then
            log "Certificate and private key match!"
        else
            error "Certificate and private key do not match!"
            exit 1
        fi
    else
        error "Certificate file not found: $CERT_DIR/$DOMAIN.crt"
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [domain] [days] [mode]"
    echo ""
    echo "Modes:"
    echo "  self-signed  - Generate self-signed certificate (default)"
    echo "  csr         - Generate CSR for commercial CA"
    echo "  letsencrypt - Generate Let's Encrypt certificate"
    echo "  validate    - Validate existing certificate"
    echo ""
    echo "Examples:"
    echo "  $0 festival-planner.example.com 365 self-signed"
    echo "  $0 festival-planner.example.com 365 csr"
    echo "  $0 festival-planner.example.com 365 letsencrypt"
    echo "  $0 festival-planner.example.com 365 validate"
}

# Main function
main() {
    MODE="${3:-self-signed}"
    
    log "SSL Certificate Generator for Festival Planner Platform"
    log "Domain: $DOMAIN"
    log "Mode: $MODE"
    
    # Pre-checks
    check_openssl
    create_cert_dir
    
    case "$MODE" in
        "self-signed")
            generate_self_signed
            ;;
        "csr")
            generate_csr
            ;;
        "letsencrypt")
            generate_letsencrypt
            ;;
        "validate")
            validate_certificate
            ;;
        "help"|"-h"|"--help")
            show_usage
            exit 0
            ;;
        *)
            error "Unknown mode: $MODE"
            show_usage
            exit 1
            ;;
    esac
    
    # Validate certificate if it was generated
    if [ "$MODE" != "validate" ] && [ "$MODE" != "help" ]; then
        validate_certificate
    fi
    
    log "Certificate generation completed!"
}

# Run main function
main "$@"