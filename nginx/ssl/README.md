# SSL/TLS Certificates

This directory contains SSL/TLS certificates for HTTPS configuration.

## Required Files

For production deployment, you need to place the following files in this directory:

1. `festival-planner.example.com.crt` - SSL certificate file
2. `festival-planner.example.com.key` - Private key file

## Certificate Generation Options

### Option 1: Production Certificates (Recommended)

Use Let's Encrypt or purchase certificates from a Certificate Authority:

#### Let's Encrypt with Certbot:
```bash
# Install certbot
sudo apt-get update
sudo apt-get install certbot

# Generate certificates
sudo certbot certonly --standalone -d festival-planner.example.com

# Copy certificates to this directory
sudo cp /etc/letsencrypt/live/festival-planner.example.com/fullchain.pem ./festival-planner.example.com.crt
sudo cp /etc/letsencrypt/live/festival-planner.example.com/privkey.pem ./festival-planner.example.com.key
```

#### Commercial Certificate Authority:
1. Purchase SSL certificate from a trusted CA
2. Follow CA's instructions to generate CSR and obtain certificate
3. Place the certificate and private key in this directory

### Option 2: Self-Signed Certificates (Development Only)

For development/testing purposes only:

```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:2048 -keyout festival-planner.example.com.key -out festival-planner.example.com.crt -days 365 -nodes -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Festival Planner/CN=festival-planner.example.com"
```

**Warning**: Self-signed certificates will show security warnings in browsers and should never be used in production.

## Certificate Renewal

### Let's Encrypt Renewal:
```bash
# Test renewal
sudo certbot renew --dry-run

# Set up auto-renewal (add to crontab)
0 12 * * * /usr/bin/certbot renew --quiet && docker-compose restart nginx
```

### Commercial Certificate Renewal:
- Monitor certificate expiration dates
- Renew certificates before expiration
- Update files in this directory
- Restart nginx container

## Security Best Practices

1. **File Permissions**: Ensure proper file permissions for certificate files
   ```bash
   chmod 644 *.crt
   chmod 600 *.key
   ```

2. **Certificate Validation**: Always validate certificates after installation
   ```bash
   openssl x509 -in festival-planner.example.com.crt -text -noout
   ```

3. **SSL Testing**: Use SSL testing tools to verify configuration
   - [SSL Labs SSL Test](https://www.ssllabs.com/ssltest/)
   - [SSL Checker](https://www.sslchecker.com/)

4. **Regular Updates**: Keep certificates up to date and monitor expiration

## Troubleshooting

### Common Issues:

1. **Certificate Chain Issues**:
   - Ensure fullchain.pem is used (includes intermediate certificates)
   - Verify certificate chain completeness

2. **Private Key Mismatch**:
   - Verify private key matches certificate
   ```bash
   openssl rsa -in festival-planner.example.com.key -pubout -outform PEM | sha256sum
   openssl x509 -in festival-planner.example.com.crt -pubkey -noout -outform PEM | sha256sum
   ```

3. **Permission Errors**:
   - Check file ownership and permissions
   - Ensure nginx can read certificate files

4. **Domain Mismatch**:
   - Verify certificate CN/SAN matches domain name
   - Update nginx configuration if domain changes

## Docker Integration

The nginx container mounts this directory as a volume:
```yaml
volumes:
  - ./nginx/ssl:/etc/nginx/ssl:ro
```

After updating certificates, restart the nginx container:
```bash
docker-compose restart nginx
```