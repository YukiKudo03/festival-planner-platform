#!/bin/bash

# Security Audit Script for Festival Planner Platform
# This script performs comprehensive security checks

set -e

# Configuration
REPORT_DIR="tmp/security-audit"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/security_audit_$TIMESTAMP.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Create report directory
create_report_dir() {
    mkdir -p "$REPORT_DIR"
    log "Created security audit report directory: $REPORT_DIR"
}

# Initialize report
init_report() {
    cat > "$REPORT_FILE" << EOF
# Security Audit Report
**Generated:** $(date)
**Platform:** Festival Planner Platform
**Environment:** ${RAILS_ENV:-development}

## Executive Summary
This report contains the results of automated security checks performed on the Festival Planner Platform.

---

EOF
}

# Check for common security vulnerabilities
check_vulnerabilities() {
    log "Checking for security vulnerabilities..."
    
    echo "## Vulnerability Assessment" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Bundle audit for Ruby dependencies
    if command -v bundle &> /dev/null; then
        echo "### Ruby Dependencies (Bundle Audit)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        if bundle exec bundle audit check --update > tmp/bundle_audit.log 2>&1; then
            echo "✅ No known vulnerabilities found in Ruby dependencies" >> "$REPORT_FILE"
        else
            echo "❌ Vulnerabilities found in Ruby dependencies:" >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
            tail -20 tmp/bundle_audit.log >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
        fi
        echo "" >> "$REPORT_FILE"
    fi
    
    # Brakeman security scan
    if command -v bundle &> /dev/null; then
        echo "### Code Security (Brakeman)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        
        if bundle exec brakeman --no-pager --quiet --format text > tmp/brakeman.log 2>&1; then
            echo "✅ No security issues found by Brakeman" >> "$REPORT_FILE"
        else
            warning_count=$(grep -c "Security Warnings" tmp/brakeman.log || echo "0")
            echo "⚠️ Brakeman found potential security issues:" >> "$REPORT_FILE"
            echo "**Warning Count:** $warning_count" >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
            head -50 tmp/brakeman.log >> "$REPORT_FILE"
            echo '```' >> "$REPORT_FILE"
        fi
        echo "" >> "$REPORT_FILE"
    fi
}

# Check file permissions
check_file_permissions() {
    log "Checking file permissions..."
    
    echo "### File Permissions" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Check for overly permissive files
    suspicious_files=()
    
    # Check config files
    for file in config/database.yml config/secrets.yml config/master.key; do
        if [ -f "$file" ]; then
            perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
            if [ "$perms" != "600" ] && [ "$perms" != "644" ]; then
                suspicious_files+=("$file (permissions: $perms)")
            fi
        fi
    done
    
    # Check secret files
    if [ -d "secrets" ]; then
        while IFS= read -r -d '' file; do
            perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
            if [ "$perms" != "600" ]; then
                suspicious_files+=("$file (permissions: $perms)")
            fi
        done < <(find secrets -type f -print0)
    fi
    
    if [ ${#suspicious_files[@]} -eq 0 ]; then
        echo "✅ File permissions are properly configured" >> "$REPORT_FILE"
    else
        echo "⚠️ Files with suspicious permissions:" >> "$REPORT_FILE"
        for file in "${suspicious_files[@]}"; do
            echo "- $file" >> "$REPORT_FILE"
        done
    fi
    echo "" >> "$REPORT_FILE"
}

# Check for hardcoded secrets
check_hardcoded_secrets() {
    log "Checking for hardcoded secrets..."
    
    echo "### Hardcoded Secrets" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Patterns to search for
    secret_patterns=(
        "password.*=.*['\"][^'\"]*['\"]"
        "api_key.*=.*['\"][^'\"]*['\"]"
        "secret.*=.*['\"][^'\"]*['\"]"
        "token.*=.*['\"][^'\"]*['\"]"
        "private_key.*=.*['\"][^'\"]*['\"]"
        "access_key.*=.*['\"][^'\"]*['\"]"
    )
    
    secret_files=()
    
    for pattern in "${secret_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            if grep -l -E "$pattern" "$file" >/dev/null 2>&1; then
                secret_files+=("$file")
            fi
        done < <(find . -name "*.rb" -o -name "*.yml" -o -name "*.yaml" -o -name "*.env*" -print0 | grep -z -v -E "(vendor/|node_modules/|\.git/)")
    done
    
    # Remove duplicates
    secret_files=($(printf "%s\n" "${secret_files[@]}" | sort -u))
    
    if [ ${#secret_files[@]} -eq 0 ]; then
        echo "✅ No hardcoded secrets detected" >> "$REPORT_FILE"
    else
        echo "⚠️ Potential hardcoded secrets found in:" >> "$REPORT_FILE"
        for file in "${secret_files[@]}"; do
            echo "- $file" >> "$REPORT_FILE"
        done
        echo "" >> "$REPORT_FILE"
        echo "**Recommendation:** Review these files and move secrets to environment variables or encrypted credentials." >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
}

# Check Docker security
check_docker_security() {
    log "Checking Docker security configuration..."
    
    echo "### Docker Security" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    docker_issues=()
    
    # Check if Dockerfile runs as non-root
    if [ -f "Dockerfile" ]; then
        if ! grep -q "USER.*[0-9]" Dockerfile; then
            docker_issues+=("Dockerfile may be running as root user")
        fi
    fi
    
    # Check docker-compose for security settings
    if [ -f "docker-compose.yml" ]; then
        if ! grep -q "read_only:" docker-compose.yml; then
            docker_issues+=("Containers are not configured as read-only")
        fi
        
        if grep -q "privileged: true" docker-compose.yml; then
            docker_issues+=("Privileged containers detected")
        fi
    fi
    
    if [ ${#docker_issues[@]} -eq 0 ]; then
        echo "✅ Docker configuration follows security best practices" >> "$REPORT_FILE"
    else
        echo "⚠️ Docker security issues:" >> "$REPORT_FILE"
        for issue in "${docker_issues[@]}"; do
            echo "- $issue" >> "$REPORT_FILE"
        done
    fi
    echo "" >> "$REPORT_FILE"
}

# Check SSL/TLS configuration
check_ssl_config() {
    log "Checking SSL/TLS configuration..."
    
    echo "### SSL/TLS Configuration" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    ssl_issues=()
    
    # Check if SSL is enforced in production
    if [ -f "config/environments/production.rb" ]; then
        if ! grep -q "config.force_ssl = true" config/environments/production.rb; then
            ssl_issues+=("SSL not enforced in production environment")
        fi
    fi
    
    # Check nginx configuration
    if [ -f "nginx/conf.d/festival_planner_platform.conf" ]; then
        if ! grep -q "ssl_protocols TLSv1.2 TLSv1.3" nginx/conf.d/festival_planner_platform.conf; then
            ssl_issues+=("Outdated SSL/TLS protocols may be enabled")
        fi
        
        if ! grep -q "Strict-Transport-Security" nginx/conf.d/festival_planner_platform.conf; then
            ssl_issues+=("HSTS header not configured")
        fi
    fi
    
    if [ ${#ssl_issues[@]} -eq 0 ]; then
        echo "✅ SSL/TLS configuration is secure" >> "$REPORT_FILE"
    else
        echo "⚠️ SSL/TLS configuration issues:" >> "$REPORT_FILE"
        for issue in "${ssl_issues[@]}"; do
            echo "- $issue" >> "$REPORT_FILE"
        done
    fi
    echo "" >> "$REPORT_FILE"
}

# Check database security
check_database_security() {
    log "Checking database security configuration..."
    
    echo "### Database Security" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    db_issues=()
    
    # Check database.yml
    if [ -f "config/database.yml" ]; then
        if grep -q "password:" config/database.yml; then
            db_issues+=("Database password may be hardcoded in database.yml")
        fi
        
        if ! grep -q "sslmode" config/database.yml; then
            db_issues+=("SSL mode not configured for database connections")
        fi
    fi
    
    # Check for database migrations with sensitive data
    if [ -d "db/migrate" ]; then
        if grep -r -l "password\|secret\|token" db/migrate/ >/dev/null 2>&1; then
            db_issues+=("Potential sensitive data in database migrations")
        fi
    fi
    
    if [ ${#db_issues[@]} -eq 0 ]; then
        echo "✅ Database security configuration is good" >> "$REPORT_FILE"
    else
        echo "⚠️ Database security issues:" >> "$REPORT_FILE"
        for issue in "${db_issues[@]}"; do
            echo "- $issue" >> "$REPORT_FILE"
        done
    fi
    echo "" >> "$REPORT_FILE"
}

# Check security headers
check_security_headers() {
    log "Checking security headers configuration..."
    
    echo "### Security Headers" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    header_issues=()
    
    # Check if security headers are configured
    if [ -f "config/application.rb" ] || [ -f "config/security.rb" ]; then
        required_headers=(
            "X-Frame-Options"
            "X-Content-Type-Options"
            "X-XSS-Protection"
            "Content-Security-Policy"
            "Strict-Transport-Security"
        )
        
        for header in "${required_headers[@]}"; do
            if ! grep -r "$header" config/ >/dev/null 2>&1; then
                header_issues+=("$header not configured")
            fi
        done
    fi
    
    if [ ${#header_issues[@]} -eq 0 ]; then
        echo "✅ Security headers are properly configured" >> "$REPORT_FILE"
    else
        echo "⚠️ Missing security headers:" >> "$REPORT_FILE"
        for issue in "${header_issues[@]}"; do
            echo "- $issue" >> "$REPORT_FILE"
        done
    fi
    echo "" >> "$REPORT_FILE"
}

# Generate recommendations
generate_recommendations() {
    log "Generating security recommendations..."
    
    echo "## Security Recommendations" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### Immediate Actions" >> "$REPORT_FILE"
    echo "1. **Update Dependencies**: Regularly update all dependencies to patch known vulnerabilities" >> "$REPORT_FILE"
    echo "2. **Secret Management**: Ensure all secrets are stored in environment variables or encrypted credentials" >> "$REPORT_FILE"
    echo "3. **File Permissions**: Review and fix any files with overly permissive permissions" >> "$REPORT_FILE"
    echo "4. **Security Headers**: Implement all recommended security headers" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### Regular Maintenance" >> "$REPORT_FILE"
    echo "1. **Security Scans**: Run security audits regularly (weekly/monthly)" >> "$REPORT_FILE"
    echo "2. **Monitoring**: Implement security monitoring and alerting" >> "$REPORT_FILE"
    echo "3. **Access Review**: Regularly review user access and permissions" >> "$REPORT_FILE"
    echo "4. **Backup Testing**: Test backup and recovery procedures regularly" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "### Compliance" >> "$REPORT_FILE"
    echo "1. **GDPR**: Ensure data protection compliance for user data" >> "$REPORT_FILE"
    echo "2. **PCI DSS**: If handling payments, ensure PCI compliance" >> "$REPORT_FILE"
    echo "3. **Audit Trail**: Maintain audit logs for security events" >> "$REPORT_FILE"
    echo "4. **Incident Response**: Have an incident response plan ready" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Generate summary
generate_summary() {
    log "Generating audit summary..."
    
    # Count issues from the report
    critical_issues=$(grep -c "❌" "$REPORT_FILE" || echo "0")
    warning_issues=$(grep -c "⚠️" "$REPORT_FILE" || echo "0")
    passed_checks=$(grep -c "✅" "$REPORT_FILE" || echo "0")
    
    # Update executive summary
    sed -i.bak "/## Executive Summary/,/---/c\\
## Executive Summary\\
This report contains the results of automated security checks performed on the Festival Planner Platform.\\
\\
**Security Status:** $([ "$critical_issues" -eq 0 ] && [ "$warning_issues" -eq 0 ] && echo "✅ GOOD" || echo "⚠️ NEEDS ATTENTION")\\
\\
**Summary:**\\
- ✅ Passed Checks: $passed_checks\\
- ⚠️ Warnings: $warning_issues\\
- ❌ Critical Issues: $critical_issues\\
\\
$([ "$critical_issues" -gt 0 ] && echo "**Action Required:** Address critical security issues immediately." || echo "")\\
$([ "$warning_issues" -gt 0 ] && echo "**Recommendation:** Review and address warning items." || echo "")\\
\\
---\\
" "$REPORT_FILE"
    
    rm -f "${REPORT_FILE}.bak"
}

# Main execution
main() {
    log "Starting security audit for Festival Planner Platform..."
    
    create_report_dir
    init_report
    
    check_vulnerabilities
    check_file_permissions
    check_hardcoded_secrets
    check_docker_security
    check_ssl_config
    check_database_security
    check_security_headers
    
    generate_recommendations
    generate_summary
    
    log "Security audit completed!"
    log "Report generated: $REPORT_FILE"
    
    # Display summary
    echo ""
    info "=== SECURITY AUDIT SUMMARY ==="
    grep -A 10 "## Executive Summary" "$REPORT_FILE" | tail -n +3 | head -n -1
    echo ""
    
    # Open report if on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "$REPORT_FILE"
    fi
}

# Run main function
main "$@"