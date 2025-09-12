# Docker Setup for LinkedIn AI Platform

This document describes how to set up and run the LinkedIn AI platform using Docker.

## Prerequisites

- Docker and Docker Compose installed on your system
- Git (to clone the repository)

## Environment Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file and add your API keys and configuration:
   - OpenAI API key for AI content generation
   - Stripe keys for payment processing
   - LinkedIn API credentials for OAuth
   - AWS credentials for file storage

## Development Setup

### Option 1: Full Development Environment

Run the complete development environment with hot reloading:

```bash
# Start all services including database, redis, and mailhog
docker-compose -f docker-compose.dev.yml up

# Or run in detached mode
docker-compose -f docker-compose.dev.yml up -d
```

This will start:
- PostgreSQL database on port 5432
- Redis for caching on port 6379
- Phoenix application on port 4000
- MailHog for email testing on port 8025

### Option 2: External Database

If you prefer to run the database externally:

```bash
# Start only the application services
docker-compose -f docker-compose.dev.yml up dev mailhog
```

## Production Setup

For production deployment:

```bash
# Build and start production services
docker-compose up --build -d
```

## Useful Commands

### Database Operations

```bash
# Run database migrations
docker-compose -f docker-compose.dev.yml exec dev mix ecto.migrate

# Reset database
docker-compose -f docker-compose.dev.yml exec dev mix ecto.reset

# Create database
docker-compose -f docker-compose.dev.yml exec dev mix ecto.create
```

### Application Commands

```bash
# Install dependencies
docker-compose -f docker-compose.dev.yml exec dev mix deps.get

# Run tests
docker-compose -f docker-compose.dev.yml exec dev mix test

# Access IEx console
docker-compose -f docker-compose.dev.yml exec dev iex -S mix

# View logs
docker-compose -f docker-compose.dev.yml logs -f dev
```

### Asset Management

```bash
# Install npm dependencies
docker-compose -f docker-compose.dev.yml exec dev npm --prefix ./assets install

# Build assets
docker-compose -f docker-compose.dev.yml exec dev mix assets.build
```

## Services

### Database (PostgreSQL)
- **Port**: 5432
- **Username**: postgres
- **Password**: postgres
- **Database**: linkedin_ai_dev

### Redis
- **Port**: 6379
- Used for caching and session storage

### MailHog (Development Email Testing)
- **SMTP Port**: 1025
- **Web UI**: http://localhost:8025
- Captures all outgoing emails for testing

### Application
- **Port**: 4000
- **URL**: http://localhost:4000

## Troubleshooting

### Port Conflicts
If you encounter port conflicts, you can modify the ports in the docker-compose files.

### Permission Issues
If you encounter permission issues on Linux:
```bash
sudo chown -R $USER:$USER .
```

### Database Connection Issues
Ensure the database service is healthy before starting the application:
```bash
docker-compose -f docker-compose.dev.yml up db
# Wait for "database system is ready to accept connections"
# Then start other services
```

### Clearing Volumes
To start fresh with clean databases:
```bash
docker-compose -f docker-compose.dev.yml down -v
docker-compose -f docker-compose.dev.yml up
```

## Environment Variables

Key environment variables for development:

- `DATABASE_URL`: PostgreSQL connection string
- `SECRET_KEY_BASE`: Phoenix secret key
- `OPENAI_API_KEY`: OpenAI API key for AI features
- `STRIPE_SECRET_KEY`: Stripe secret key for payments
- `LINKEDIN_CLIENT_ID`: LinkedIn OAuth client ID
- `AWS_ACCESS_KEY_ID`: AWS access key for file storage

See `.env.example` for a complete list of required variables.