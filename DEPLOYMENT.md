# Production Deployment Guide

This guide provides step-by-step instructions for deploying the LinkedIn AI Platform to production.

## Quick Start

For a complete automated deployment:

```bash
# 1. Clone the repository
git clone <repository-url>
cd linkedin-ai-platform

# 2. Copy and configure environment variables
cp .env.prod.example .env.prod
# Edit .env.prod with your actual values

# 3. Run the deployment script
sudo ./scripts/deploy.sh deploy

# 4. (Optional) Set up SSL certificates
sudo ./scripts/deploy.sh deploy --ssl your-domain.com
```

## Prerequisites

### System Requirements

- **Operating System**: Ubuntu 20.04+ or similar Linux distribution
- **CPU**: 2+ cores (4+ recommended for production)
- **RAM**: 4GB minimum (8GB+ recommended)
- **Storage**: 20GB minimum (SSD recommended)
- **Network**: Static IP address and domain name

### Required Software

1. **Docker & Docker Compose**
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   
   # Install Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

2. **Git**
   ```bash
   sudo apt update
   sudo apt install git
   ```

3. **SSL Certificate Tool (Optional)**
   ```bash
   sudo apt install certbot python3-certbot-nginx
   ```

## Configuration

### Environment Variables

Copy the example environment file and configure it:

```bash
cp .env.prod.example .env.prod
```

#### Required Variables

```bash
# Application
SECRET_KEY_BASE=your_64_character_secret_key_base
PHX_HOST=your-domain.com
DB_PASSWORD=your_secure_database_password

# External APIs
OPENAI_API_KEY=sk-your_openai_api_key
LINKEDIN_CLIENT_ID=your_linkedin_client_id
LINKEDIN_CLIENT_SECRET=your_linkedin_client_secret
STRIPE_PUBLIC_KEY=pk_live_your_stripe_public_key
STRIPE_SECRET_KEY=sk_live_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Email
SMTP_HOST=smtp.your-provider.com
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password
FROM_EMAIL=noreply@your-domain.com
```

#### Generate Secret Key

```bash
# Generate a secure secret key
openssl rand -base64 64
```

### SSL Certificates

#### Option 1: Let's Encrypt (Recommended)

The deployment script can automatically set up Let's Encrypt certificates:

```bash
sudo ./scripts/deploy.sh deploy --ssl your-domain.com
```

#### Option 2: Custom Certificates

Place your SSL certificates in the `nginx/ssl/` directory:

```bash
mkdir -p nginx/ssl
cp your-certificate.pem nginx/ssl/fullchain.pem
cp your-private-key.pem nginx/ssl/privkey.pem
chmod 644 nginx/ssl/fullchain.pem
chmod 600 nginx/ssl/privkey.pem
```

## Deployment Process

### Automated Deployment

The recommended way to deploy is using the automated deployment script:

```bash
sudo ./scripts/deploy.sh deploy
```

This script will:
1. Check prerequisites
2. Create necessary directories
3. Backup current deployment (if exists)
4. Build the application
5. Start all services
6. Run database migrations
7. Create performance indexes
8. Seed the database
9. Create admin user
10. Perform health checks
11. Set up monitoring

### Manual Deployment

If you prefer manual control over the deployment process:

#### 1. Build and Start Services

```bash
# Build the application
docker-compose -f docker-compose.prod.yml build

# Start database and Redis first
docker-compose -f docker-compose.prod.yml up -d db redis

# Wait for database to be ready
docker-compose -f docker-compose.prod.yml exec db pg_isready -U linkedin_ai

# Start all services
docker-compose -f docker-compose.prod.yml up -d
```

#### 2. Run Database Setup

```bash
# Run migrations
docker-compose -f docker-compose.prod.yml exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.migrate()"

# Create performance indexes
docker-compose -f docker-compose.prod.yml exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.create_indexes()"

# Seed database
docker-compose -f docker-compose.prod.yml exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.seed()"

# Create admin user
docker-compose -f docker-compose.prod.yml exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.create_admin_user()"
```

#### 3. Verify Deployment

```bash
# Check service status
docker-compose -f docker-compose.prod.yml ps

# Check application health
curl http://localhost:4000/health

# Check logs
docker-compose -f docker-compose.prod.yml logs web
```

## Post-Deployment

### Admin Access

After deployment, you can access the admin panel:

1. **URL**: `https://your-domain.com/admin`
2. **Credentials**: Check the deployment logs for auto-generated admin credentials
3. **Change Password**: Log in and change the default password immediately

### Monitoring

The deployment includes monitoring services:

- **Grafana**: `http://your-domain.com:3000`
  - Username: `admin`
  - Password: Set in `GRAFANA_PASSWORD` environment variable

- **Prometheus**: `http://your-domain.com:9090`

- **Application Dashboard**: `https://your-domain.com/dashboard`

### Backup Setup

Set up automated backups:

```bash
# Add to crontab for daily backups at 2 AM
sudo crontab -e

# Add this line:
0 2 * * * /path/to/linkedin-ai-platform/scripts/backup_db.sh
```

### Log Rotation

The deployment script automatically sets up log rotation. Logs are rotated daily and kept for 30 days.

## Maintenance

### Updates

To update the application:

```bash
# Pull latest code
git pull origin main

# Redeploy
sudo ./scripts/deploy.sh deploy
```

### Rollback

If something goes wrong, you can rollback:

```bash
sudo ./scripts/deploy.sh rollback
```

### Database Backup

Manual backup:

```bash
./scripts/backup_db.sh
```

### Database Restore

```bash
./scripts/restore_db.sh /backups/backup_20231201_120000.sql.gz
```

### Scaling

To scale the application:

```bash
# Scale web workers
docker-compose -f docker-compose.prod.yml up -d --scale web=3

# Scale background workers
docker-compose -f docker-compose.prod.yml up -d --scale worker=2
```

## Troubleshooting

### Common Issues

#### 1. Application Won't Start

```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs web

# Check database connectivity
docker-compose -f docker-compose.prod.yml exec web /app/bin/linkedin_ai eval "LinkedinAi.Repo.query!(\"SELECT 1\")"
```

#### 2. Database Connection Issues

```bash
# Check database status
docker-compose -f docker-compose.prod.yml ps db

# Check database logs
docker-compose -f docker-compose.prod.yml logs db

# Test connection
docker-compose -f docker-compose.prod.yml exec db psql -U linkedin_ai -d linkedin_ai_prod -c "SELECT version();"
```

#### 3. SSL Certificate Issues

```bash
# Check certificate validity
openssl x509 -in nginx/ssl/fullchain.pem -text -noout

# Renew Let's Encrypt certificate
sudo certbot renew
sudo docker-compose -f docker-compose.prod.yml restart nginx
```

#### 4. High Memory Usage

```bash
# Check memory usage
docker stats

# Restart services if needed
docker-compose -f docker-compose.prod.yml restart web worker
```

### Performance Optimization

#### Database Optimization

```bash
# Analyze database performance
docker-compose -f docker-compose.prod.yml exec db psql -U linkedin_ai -d linkedin_ai_prod -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;"
```

#### Application Monitoring

```bash
# Check application metrics
curl http://localhost:4000/metrics

# View live dashboard
# Visit https://your-domain.com/dashboard
```

## Security

### Security Checklist

- [ ] SSL/TLS certificates configured and auto-renewing
- [ ] Database credentials secured and rotated regularly
- [ ] API keys encrypted and stored securely
- [ ] Regular security updates applied
- [ ] Firewall configured (only ports 80, 443, 22 open)
- [ ] Backup encryption enabled
- [ ] Monitoring and alerting configured
- [ ] Admin panel access restricted
- [ ] Rate limiting enabled
- [ ] CSRF protection enabled

### Firewall Configuration

```bash
# Configure UFW firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### Regular Maintenance

1. **Weekly**: Review logs and monitoring alerts
2. **Monthly**: Update system packages and Docker images
3. **Quarterly**: Review and rotate API keys and passwords
4. **Annually**: Security audit and penetration testing

## Support

For deployment issues:

1. Check the logs: `docker-compose -f docker-compose.prod.yml logs`
2. Review this documentation
3. Check the troubleshooting section
4. Contact support with detailed error messages and logs

## Disaster Recovery

### Backup Strategy

- **Database**: Daily automated backups with 30-day retention
- **Files**: Weekly backups to S3
- **Configuration**: Version-controlled in Git

### Recovery Procedures

1. **Complete System Failure**: Provision new server and restore from backups
2. **Database Corruption**: Restore from latest backup
3. **Application Issues**: Rollback to previous version

### Recovery Time Objectives

- **RTO (Recovery Time Objective)**: 4 hours
- **RPO (Recovery Point Objective)**: 24 hours