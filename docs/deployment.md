# Deployment Guide

This guide covers deploying the LinkedIn AI Platform to various environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Configuration](#environment-configuration)
- [Docker Deployment](#docker-deployment)
- [Database Setup](#database-setup)
- [SSL Configuration](#ssl-configuration)
- [Monitoring Setup](#monitoring-setup)
- [Backup and Recovery](#backup-and-recovery)

## Prerequisites

### System Requirements

- **CPU**: 2+ cores recommended
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 20GB minimum, SSD recommended
- **OS**: Ubuntu 20.04+ or similar Linux distribution

### Required Software

- Docker 20.10+
- Docker Compose 2.0+
- PostgreSQL 14+ (if not using Docker)
- Redis 6+ (if not using Docker)
- SSL certificate (Let's Encrypt recommended)

## Environment Configuration

### Production Environment Variables

Create a `.env.prod` file with the following variables:

```bash
# Application
MIX_ENV=prod
SECRET_KEY_BASE=your_64_character_secret_key_base
PHX_HOST=your-domain.com
PORT=4000
PHX_SERVER=true

# Database
DATABASE_URL=postgresql://username:password@db:5432/linkedin_ai_prod

# Redis
REDIS_URL=redis://redis:6379/0

# External APIs
OPENAI_API_KEY=your_openai_api_key
LINKEDIN_CLIENT_ID=your_linkedin_client_id
LINKEDIN_CLIENT_SECRET=your_linkedin_client_secret
STRIPE_PUBLIC_KEY=pk_live_your_stripe_public_key
STRIPE_SECRET_KEY=sk_live_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Email (Swoosh)
SMTP_HOST=smtp.your-provider.com
SMTP_PORT=587
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password

# AWS S3 (for file storage)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-s3-bucket

# Monitoring
SENTRY_DSN=your_sentry_dsn
```

### Generating Secret Key Base

```bash
mix phx.gen.secret
```

## Docker Deployment

### Production Docker Compose

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: linkedin_ai_prod
      POSTGRES_USER: linkedin_ai
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U linkedin_ai"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  web:
    build:
      context: .
      dockerfile: Dockerfile.prod
    ports:
      - "4000:4000"
    environment:
      - MIX_ENV=prod
      - DATABASE_URL=postgresql://linkedin_ai:${DB_PASSWORD}@db:5432/linkedin_ai_prod
      - REDIS_URL=redis://redis:6379/0
    env_file:
      - .env.prod
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - web
    restart: unless-stopped

volumes:
  postgres_data:
```

### Production Dockerfile

Create `Dockerfile.prod`:

```dockerfile
# Build stage
FROM elixir:1.15-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base npm git python3

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only=prod
RUN mkdir config

# Copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Compile the release
COPY priv priv
COPY lib lib
COPY assets assets

# Compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# Start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM alpine:3.18 AS app

RUN apk add --no-cache libstdc++ openssl ncurses-libs curl

WORKDIR /app

RUN chown nobody /app

# Set the runtime ENV
ENV MIX_ENV=prod

# Only copy the final release from the build stage
COPY --from=build --chown=nobody:root /app/_build/${MIX_ENV}/rel/linkedin_ai ./

USER nobody

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

CMD ["/app/bin/server"]
```

### Deployment Steps

1. **Clone the repository on your server**
   ```bash
   git clone <repository-url>
   cd linkedin-ai-platform
   ```

2. **Set up environment variables**
   ```bash
   cp .env.example .env.prod
   # Edit .env.prod with production values
   ```

3. **Build and start services**
   ```bash
   docker-compose -f docker-compose.prod.yml up -d --build
   ```

4. **Run database migrations**
   ```bash
   docker-compose -f docker-compose.prod.yml exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.migrate"
   ```

5. **Create admin user**
   ```bash
   docker-compose -f docker-compose.prod.yml exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.create_admin_user"
   ```

## Database Setup

### Migration Strategy

The application uses Ecto migrations for database schema management.

#### Running Migrations

```bash
# In development
mix ecto.migrate

# In production (Docker)
docker-compose exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.migrate"
```

#### Rollback Migrations

```bash
# Rollback last migration
mix ecto.rollback

# Rollback to specific version
mix ecto.rollback --to 20231201000000
```

### Database Backup

#### Automated Backup Script

Create `scripts/backup_db.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="linkedin_ai_prod"

# Create backup
docker-compose exec -T db pg_dump -U linkedin_ai $DB_NAME | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

# Keep only last 7 days of backups
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: backup_$DATE.sql.gz"
```

#### Restore from Backup

```bash
# Stop the application
docker-compose stop web

# Restore database
gunzip -c /backups/backup_20231201_120000.sql.gz | docker-compose exec -T db psql -U linkedin_ai linkedin_ai_prod

# Start the application
docker-compose start web
```

## SSL Configuration

### Nginx Configuration

Create `nginx.conf`:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream phoenix {
        server web:4000;
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name your-domain.com;
        return 301 https://$server_name$request_uri;
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;

        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";

        location / {
            proxy_pass http://phoenix;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
}
```

### Let's Encrypt SSL

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal (add to crontab)
0 12 * * * /usr/bin/certbot renew --quiet
```

## Monitoring Setup

### Health Checks

The application provides several health check endpoints:

- `/health` - Basic application health
- `/health/db` - Database connectivity
- `/health/redis` - Redis connectivity
- `/health/external` - External API status

### Logging

Configure structured logging in `config/prod.exs`:

```elixir
config :logger,
  level: :info,
  backends: [:console, {LoggerFileBackend, :info_log}]

config :logger, :info_log,
  path: "/var/log/linkedin_ai/info.log",
  level: :info,
  format: "$time $metadata[$level] $message\n"
```

### Monitoring with Prometheus

Add to `docker-compose.prod.yml`:

```yaml
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    restart: unless-stopped

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    restart: unless-stopped
```

## Backup and Recovery

### Automated Backup Strategy

1. **Database Backups**: Daily automated backups with 30-day retention
2. **File Backups**: Weekly backups of uploaded files to S3
3. **Configuration Backups**: Version-controlled configuration files

### Disaster Recovery Plan

1. **RTO (Recovery Time Objective)**: 4 hours
2. **RPO (Recovery Point Objective)**: 24 hours
3. **Backup Locations**: Primary (local), Secondary (S3), Tertiary (offsite)

### Recovery Procedures

#### Complete System Recovery

1. **Provision new infrastructure**
2. **Restore database from latest backup**
3. **Deploy application from Git repository**
4. **Restore file uploads from S3 backup**
5. **Update DNS records**
6. **Verify system functionality**

#### Partial Recovery

1. **Database corruption**: Restore from latest backup
2. **Application issues**: Rollback to previous version
3. **File system issues**: Restore files from S3

## Troubleshooting

### Common Issues

#### Application Won't Start

```bash
# Check logs
docker-compose logs web

# Check database connectivity
docker-compose exec web /app/bin/linkedin_ai eval "LinkedinAi.Repo.query!(\"SELECT 1\")"
```

#### High Memory Usage

```bash
# Monitor memory usage
docker stats

# Check for memory leaks
docker-compose exec web /app/bin/linkedin_ai remote
```

#### SSL Certificate Issues

```bash
# Check certificate validity
openssl x509 -in /path/to/cert.pem -text -noout

# Renew Let's Encrypt certificate
sudo certbot renew
```

### Performance Optimization

1. **Database**: Add appropriate indexes, optimize queries
2. **Caching**: Implement Redis caching for frequently accessed data
3. **CDN**: Use CloudFlare or similar for static assets
4. **Load Balancing**: Add multiple application instances behind load balancer

## Security Checklist

- [ ] SSL/TLS certificates configured and auto-renewing
- [ ] Database credentials secured and rotated regularly
- [ ] API keys encrypted and stored securely
- [ ] Regular security updates applied
- [ ] Firewall configured to allow only necessary ports
- [ ] Backup encryption enabled
- [ ] Monitoring and alerting configured
- [ ] Security headers configured in Nginx
- [ ] Rate limiting implemented
- [ ] CSRF protection enabled