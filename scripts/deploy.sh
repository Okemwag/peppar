#!/bin/bash

# LinkedIn AI Platform Deployment Script
# This script handles the complete deployment process for production

set -e

# Configuration
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env.prod"
BACKUP_DIR="/backups"
LOG_FILE="/var/log/linkedin_ai_deploy.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a $LOG_FILE
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a $LOG_FILE
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a $LOG_FILE
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run this script as root or with sudo"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if environment file exists
    if [ ! -f "$ENV_FILE" ]; then
        error "Environment file $ENV_FILE not found. Please create it from .env.prod.example"
        exit 1
    fi
    
    # Check if SSL certificates exist
    if [ ! -f "nginx/ssl/fullchain.pem" ] || [ ! -f "nginx/ssl/privkey.pem" ]; then
        warning "SSL certificates not found. HTTPS will not work until certificates are provided."
    fi
    
    log "Prerequisites check completed"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p $BACKUP_DIR
    mkdir -p /var/log/linkedin_ai
    mkdir -p nginx/ssl
    
    # Set proper permissions
    chown -R 1000:1000 $BACKUP_DIR
    chmod 755 $BACKUP_DIR
    
    log "Directories created successfully"
}

# Backup current deployment
backup_current() {
    log "Creating backup of current deployment..."
    
    if docker-compose -f $COMPOSE_FILE ps | grep -q "Up"; then
        # Create database backup
        ./scripts/backup_db.sh
        
        # Backup current environment file
        cp $ENV_FILE "${BACKUP_DIR}/env_backup_$(date +%Y%m%d_%H%M%S)"
        
        log "Backup completed successfully"
    else
        log "No running deployment found, skipping backup"
    fi
}

# Pull latest images
pull_images() {
    log "Pulling latest Docker images..."
    
    docker-compose -f $COMPOSE_FILE pull
    
    log "Images pulled successfully"
}

# Build application
build_application() {
    log "Building application..."
    
    docker-compose -f $COMPOSE_FILE build --no-cache web worker
    
    if [ $? -eq 0 ]; then
        log "Application built successfully"
    else
        error "Application build failed"
        exit 1
    fi
}

# Start services
start_services() {
    log "Starting services..."
    
    # Start database and Redis first
    docker-compose -f $COMPOSE_FILE up -d db redis
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker-compose -f $COMPOSE_FILE exec -T db pg_isready -U linkedin_ai; then
            break
        fi
        sleep 2
        timeout=$((timeout - 2))
    done
    
    if [ $timeout -le 0 ]; then
        error "Database failed to start within 60 seconds"
        exit 1
    fi
    
    # Start all other services
    docker-compose -f $COMPOSE_FILE up -d
    
    log "Services started successfully"
}

# Run database migrations
run_migrations() {
    log "Running database migrations..."
    
    docker-compose -f $COMPOSE_FILE exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.migrate()"
    
    if [ $? -eq 0 ]; then
        log "Database migrations completed successfully"
    else
        error "Database migrations failed"
        exit 1
    fi
}

# Create performance indexes
create_indexes() {
    log "Creating performance indexes..."
    
    docker-compose -f $COMPOSE_FILE exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.create_indexes()"
    
    if [ $? -eq 0 ]; then
        log "Performance indexes created successfully"
    else
        warning "Failed to create some performance indexes (this is non-critical)"
    fi
}

# Seed database
seed_database() {
    log "Seeding database..."
    
    docker-compose -f $COMPOSE_FILE exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.seed()"
    
    if [ $? -eq 0 ]; then
        log "Database seeded successfully"
    else
        warning "Database seeding failed (this may be expected if already seeded)"
    fi
}

# Create admin user
create_admin() {
    log "Creating admin user..."
    
    docker-compose -f $COMPOSE_FILE exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.create_admin_user()"
    
    if [ $? -eq 0 ]; then
        log "Admin user creation completed"
    else
        warning "Admin user creation failed (user may already exist)"
    fi
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Wait for application to be ready
    timeout=120
    while [ $timeout -gt 0 ]; do
        if curl -f http://localhost:4000/health > /dev/null 2>&1; then
            log "Application is healthy"
            return 0
        fi
        sleep 5
        timeout=$((timeout - 5))
    done
    
    error "Application failed health check"
    return 1
}

# Validate external APIs
validate_apis() {
    log "Validating external API connections..."
    
    docker-compose -f $COMPOSE_FILE exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.check_external_apis()"
    
    if [ $? -eq 0 ]; then
        log "External API validation completed"
    else
        warning "Some external APIs may not be accessible"
    fi
}

# Setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    
    # Start Prometheus and Grafana
    docker-compose -f $COMPOSE_FILE up -d prometheus grafana
    
    log "Monitoring services started"
    log "Grafana available at: http://localhost:3000"
    log "Prometheus available at: http://localhost:9090"
}

# Setup SSL certificates (Let's Encrypt)
setup_ssl() {
    if [ "$1" = "--ssl" ] && [ ! -z "$2" ]; then
        log "Setting up SSL certificates for domain: $2"
        
        # Install certbot if not present
        if ! command -v certbot &> /dev/null; then
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
        fi
        
        # Stop nginx temporarily
        docker-compose -f $COMPOSE_FILE stop nginx
        
        # Obtain certificate
        certbot certonly --standalone -d $2 --non-interactive --agree-tos --email admin@$2
        
        # Copy certificates to nginx directory
        cp /etc/letsencrypt/live/$2/fullchain.pem nginx/ssl/
        cp /etc/letsencrypt/live/$2/privkey.pem nginx/ssl/
        
        # Set proper permissions
        chown root:root nginx/ssl/*.pem
        chmod 644 nginx/ssl/fullchain.pem
        chmod 600 nginx/ssl/privkey.pem
        
        # Start nginx
        docker-compose -f $COMPOSE_FILE start nginx
        
        # Setup auto-renewal
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --deploy-hook 'docker-compose -f $PWD/$COMPOSE_FILE restart nginx'") | crontab -
        
        log "SSL certificates configured successfully"
    fi
}

# Cleanup old resources
cleanup() {
    log "Cleaning up old resources..."
    
    # Remove unused Docker images
    docker image prune -f
    
    # Remove unused volumes
    docker volume prune -f
    
    # Clean up old application data
    docker-compose -f $COMPOSE_FILE exec web /app/bin/linkedin_ai eval "LinkedinAi.Release.cleanup_old_data()"
    
    log "Cleanup completed"
}

# Setup log rotation
setup_log_rotation() {
    log "Setting up log rotation..."
    
    cat > /etc/logrotate.d/linkedin_ai << EOF
/var/log/linkedin_ai/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker-compose -f $PWD/$COMPOSE_FILE restart web worker
    endscript
}
EOF
    
    log "Log rotation configured"
}

# Main deployment function
deploy() {
    log "Starting LinkedIn AI Platform deployment..."
    
    check_prerequisites
    create_directories
    backup_current
    pull_images
    build_application
    start_services
    run_migrations
    create_indexes
    seed_database
    create_admin
    
    if health_check; then
        validate_apis
        setup_monitoring
        cleanup
        setup_log_rotation
        
        log "Deployment completed successfully!"
        log "Application is available at: http://localhost:4000"
        log "Admin panel: http://localhost:4000/admin"
        log "Monitoring: http://localhost:3000 (Grafana)"
        
        # Display admin credentials if created
        if [ ! -z "$ADMIN_EMAIL" ]; then
            log "Admin email: $ADMIN_EMAIL"
        fi
        
    else
        error "Deployment failed - application is not healthy"
        log "Check logs with: docker-compose -f $COMPOSE_FILE logs"
        exit 1
    fi
}

# Rollback function
rollback() {
    log "Rolling back to previous deployment..."
    
    # Stop current services
    docker-compose -f $COMPOSE_FILE down
    
    # Restore from backup
    latest_backup=$(ls -t $BACKUP_DIR/backup_*.sql.gz | head -n1)
    if [ ! -z "$latest_backup" ]; then
        ./scripts/restore_db.sh "$latest_backup"
    fi
    
    # Restore previous environment
    latest_env_backup=$(ls -t $BACKUP_DIR/env_backup_* | head -n1)
    if [ ! -z "$latest_env_backup" ]; then
        cp "$latest_env_backup" $ENV_FILE
    fi
    
    # Start services
    start_services
    
    log "Rollback completed"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTION]"
    echo "Options:"
    echo "  deploy              Deploy the application"
    echo "  rollback            Rollback to previous deployment"
    echo "  --ssl DOMAIN        Setup SSL certificates for domain"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy"
    echo "  $0 deploy --ssl example.com"
    echo "  $0 rollback"
}

# Main script logic
case "$1" in
    deploy)
        check_root
        setup_ssl $2 $3
        deploy
        ;;
    rollback)
        check_root
        rollback
        ;;
    --help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac