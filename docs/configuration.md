# Configuration Guide

This guide covers all configuration options for the LinkedIn AI Platform.

## Table of Contents

- [Environment Variables](#environment-variables)
- [Database Configuration](#database-configuration)
- [External API Configuration](#external-api-configuration)
- [Subscription Plans](#subscription-plans)
- [Email Configuration](#email-configuration)
- [Caching Configuration](#caching-configuration)
- [Security Configuration](#security-configuration)
- [Monitoring Configuration](#monitoring-configuration)

## Environment Variables

### Required Variables

#### Application Core
```bash
# Application environment
MIX_ENV=dev|test|prod

# Secret key for encryption (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your_64_character_secret_key_base

# Application host and port
PHX_HOST=localhost
PORT=4000
PHX_SERVER=true  # Set to true in production
```

#### Database
```bash
# PostgreSQL connection URL
DATABASE_URL=postgresql://username:password@localhost/linkedin_ai_dev

# Database pool size (default: 10)
POOL_SIZE=10
```

#### Redis (Optional)
```bash
# Redis connection URL for caching
REDIS_URL=redis://localhost:6379/0
```

### External API Configuration

#### OpenAI Configuration
```bash
# OpenAI API key (required for content generation)
OPENAI_API_KEY=sk-your_openai_api_key

# OpenAI model to use (default: gpt-4)
OPENAI_MODEL=gpt-4

# OpenAI API timeout in milliseconds (default: 30000)
OPENAI_TIMEOUT=30000

# Maximum tokens for content generation (default: 1000)
OPENAI_MAX_TOKENS=1000
```

#### LinkedIn API Configuration
```bash
# LinkedIn OAuth application credentials
LINKEDIN_CLIENT_ID=your_linkedin_client_id
LINKEDIN_CLIENT_SECRET=your_linkedin_client_secret

# LinkedIn API base URL (default: https://api.linkedin.com)
LINKEDIN_API_BASE_URL=https://api.linkedin.com

# LinkedIn API timeout in milliseconds (default: 15000)
LINKEDIN_TIMEOUT=15000
```

#### Stripe Configuration
```bash
# Stripe API keys
STRIPE_PUBLIC_KEY=pk_test_your_stripe_public_key  # pk_live_ for production
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key  # sk_live_ for production

# Stripe webhook secret for signature verification
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Stripe API version (default: 2023-10-16)
STRIPE_API_VERSION=2023-10-16
```

### Email Configuration (Swoosh)

#### SMTP Configuration
```bash
# SMTP server settings
SMTP_HOST=smtp.your-provider.com
SMTP_PORT=587
SMTP_USERNAME=your_smtp_username
SMTP_PASSWORD=your_smtp_password

# Email sender information
FROM_EMAIL=noreply@your-domain.com
FROM_NAME=LinkedIn AI Platform
```

#### Popular SMTP Providers

**Gmail**
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

**SendGrid**
```bash
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your-sendgrid-api-key
```

**Mailgun**
```bash
SMTP_HOST=smtp.mailgun.org
SMTP_PORT=587
SMTP_USERNAME=your-mailgun-username
SMTP_PASSWORD=your-mailgun-password
```

### AWS S3 Configuration (Optional)

```bash
# AWS credentials for file storage
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-s3-bucket-name
```

### Monitoring and Logging

```bash
# Sentry DSN for error tracking (optional)
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id

# Log level (debug, info, warn, error)
LOG_LEVEL=info

# Enable/disable telemetry (true/false)
TELEMETRY_ENABLED=true
```

## Database Configuration

### Development Configuration

In `config/dev.exs`:

```elixir
config :linkedin_ai, LinkedinAi.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "linkedin_ai_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

### Production Configuration

In `config/runtime.exs`:

```elixir
config :linkedin_ai, LinkedinAi.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: [:inet6]
```

### Connection Pool Configuration

```elixir
# Adjust based on your server capacity
config :linkedin_ai, LinkedinAi.Repo,
  pool_size: 15,
  queue_target: 5000,
  queue_interval: 5000
```

## External API Configuration

### OpenAI Client Configuration

In `config/config.exs`:

```elixir
config :linkedin_ai, LinkedinAi.AI.OpenAIClient,
  api_key: System.get_env("OPENAI_API_KEY"),
  model: System.get_env("OPENAI_MODEL") || "gpt-4",
  max_tokens: String.to_integer(System.get_env("OPENAI_MAX_TOKENS") || "1000"),
  timeout: String.to_integer(System.get_env("OPENAI_TIMEOUT") || "30000"),
  retry_attempts: 3,
  retry_delay: 1000
```

### LinkedIn Client Configuration

```elixir
config :linkedin_ai, LinkedinAi.Social.LinkedInClient,
  client_id: System.get_env("LINKEDIN_CLIENT_ID"),
  client_secret: System.get_env("LINKEDIN_CLIENT_SECRET"),
  base_url: System.get_env("LINKEDIN_API_BASE_URL") || "https://api.linkedin.com",
  timeout: String.to_integer(System.get_env("LINKEDIN_TIMEOUT") || "15000"),
  rate_limit: [
    requests_per_minute: 100,
    requests_per_hour: 1000
  ]
```

### Stripe Configuration

```elixir
config :stripity_stripe,
  api_key: System.get_env("STRIPE_SECRET_KEY"),
  public_key: System.get_env("STRIPE_PUBLIC_KEY"),
  webhook_secret: System.get_env("STRIPE_WEBHOOK_SECRET"),
  api_version: System.get_env("STRIPE_API_VERSION") || "2023-10-16"
```

## Subscription Plans

### Plan Configuration

In `config/config.exs`:

```elixir
config :linkedin_ai, :subscription_plans,
  basic: %{
    name: "Basic",
    price: 2500,  # $25.00 in cents
    currency: "usd",
    interval: "month",
    features: %{
      content_generation_limit: 10,
      profile_analysis: :basic,
      analytics_history_days: 30,
      support_level: :email
    }
  },
  pro: %{
    name: "Pro",
    price: 4500,  # $45.00 in cents
    currency: "usd",
    interval: "month",
    features: %{
      content_generation_limit: :unlimited,
      profile_analysis: :advanced,
      analytics_history_days: :unlimited,
      competitor_analysis: true,
      support_level: :priority
    }
  }
```

### Usage Limits Configuration

```elixir
config :linkedin_ai, :usage_limits,
  basic: %{
    content_generation_per_month: 10,
    profile_analyses_per_month: 2,
    api_calls_per_day: 100
  },
  pro: %{
    content_generation_per_month: :unlimited,
    profile_analyses_per_month: :unlimited,
    api_calls_per_day: 1000
  }
```

## Email Configuration

### Swoosh Configuration

In `config/runtime.exs`:

```elixir
config :linkedin_ai, LinkedinAi.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("SMTP_HOST"),
  port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  tls: :always,
  auth: :always,
  retries: 3
```

### Email Templates Configuration

```elixir
config :linkedin_ai, :email_templates,
  welcome: %{
    subject: "Welcome to LinkedIn AI Platform!",
    template: "welcome.html"
  },
  subscription_created: %{
    subject: "Subscription Activated",
    template: "subscription_created.html"
  },
  subscription_cancelled: %{
    subject: "Subscription Cancelled",
    template: "subscription_cancelled.html"
  },
  usage_limit_reached: %{
    subject: "Usage Limit Reached",
    template: "usage_limit_reached.html"
  }
```

## Caching Configuration

### Redis Configuration

In `config/runtime.exs`:

```elixir
config :linkedin_ai, LinkedinAi.Cache,
  adapter: Cachex,
  redis_url: System.get_env("REDIS_URL"),
  pools: [
    primary: [
      size: 10,
      max_overflow: 20
    ]
  ]
```

### Cache Settings

```elixir
config :linkedin_ai, :cache_settings,
  # Content generation cache (5 minutes)
  content_generation_ttl: 300,
  
  # Profile analysis cache (1 hour)
  profile_analysis_ttl: 3600,
  
  # Analytics cache (15 minutes)
  analytics_ttl: 900,
  
  # User session cache (24 hours)
  session_ttl: 86400
```

## Security Configuration

### Authentication Configuration

```elixir
config :linkedin_ai, LinkedinAiWeb.UserAuth,
  # Session timeout in seconds (default: 24 hours)
  session_timeout: 86400,
  
  # Remember me duration in seconds (default: 30 days)
  remember_me_duration: 2_592_000,
  
  # Password requirements
  password_min_length: 8,
  password_require_uppercase: true,
  password_require_lowercase: true,
  password_require_numbers: true,
  password_require_symbols: false
```

### Rate Limiting Configuration

```elixir
config :linkedin_ai, :rate_limiting,
  # API endpoints
  api_requests_per_minute: 60,
  api_requests_per_hour: 1000,
  
  # Content generation
  content_generation_per_minute: 5,
  content_generation_per_hour: 50,
  
  # Authentication attempts
  login_attempts_per_minute: 5,
  registration_attempts_per_hour: 10
```

### CORS Configuration

```elixir
config :cors_plug,
  origin: ["https://your-domain.com", "https://www.your-domain.com"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
  headers: ["Authorization", "Content-Type", "Accept", "Origin", "User-Agent", "DNT", "Cache-Control", "X-Mx-ReqToken", "Keep-Alive", "X-Requested-With", "If-Modified-Since", "X-CSRF-Token"]
```

## Monitoring Configuration

### Phoenix LiveDashboard

In `config/prod.exs`:

```elixir
config :linkedin_ai, LinkedinAiWeb.Endpoint,
  live_dashboard: [
    metrics: LinkedinAiWeb.Telemetry,
    additional_pages: [
      broadway: BroadwayDashboard,
      oban: Oban.Web.Dashboard
    ]
  ]
```

### Telemetry Configuration

```elixir
config :linkedin_ai, LinkedinAiWeb.Telemetry,
  metrics: [
    # Phoenix Metrics
    summary("phoenix.endpoint.stop.duration",
      unit: {:native, :millisecond}
    ),
    summary("phoenix.router_dispatch.stop.duration",
      tags: [:route],
      unit: {:native, :millisecond}
    ),
    
    # Database Metrics
    summary("linkedin_ai.repo.query.total_time",
      unit: {:native, :millisecond}
    ),
    counter("linkedin_ai.repo.query.count"),
    
    # Custom Business Metrics
    counter("linkedin_ai.content.generated.count"),
    counter("linkedin_ai.subscriptions.created.count"),
    counter("linkedin_ai.users.registered.count")
  ]
```

### Logging Configuration

```elixir
config :logger,
  level: String.to_atom(System.get_env("LOG_LEVEL") || "info"),
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

# Structured logging for production
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :subscription_id]
```

## Environment-Specific Configurations

### Development Environment

```elixir
# config/dev.exs
config :linkedin_ai, LinkedinAiWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:linkedin_ai, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:linkedin_ai, ~w(--watch)]}
  ]

# Enable dev routes for dashboard and mailbox
config :linkedin_ai, dev_routes: true

# Disable SSL in development
config :linkedin_ai, LinkedinAiWeb.Endpoint,
  https: false
```

### Test Environment

```elixir
# config/test.exs
config :linkedin_ai, LinkedinAi.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Disable external API calls in tests
config :linkedin_ai, :external_apis,
  openai_enabled: false,
  linkedin_enabled: false,
  stripe_enabled: false

# Use test adapters
config :linkedin_ai, LinkedinAi.Mailer, adapter: Swoosh.Adapters.Test
```

### Production Environment

```elixir
# config/prod.exs
config :linkedin_ai, LinkedinAiWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true

# SSL configuration
config :linkedin_ai, LinkedinAiWeb.Endpoint,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH")
  ]

# Force SSL
config :linkedin_ai, LinkedinAiWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]]
```

## Configuration Validation

### Startup Validation

Create `lib/linkedin_ai/config_validator.ex`:

```elixir
defmodule LinkedinAi.ConfigValidator do
  @moduledoc """
  Validates application configuration at startup.
  """

  def validate! do
    validate_database_config!()
    validate_external_apis!()
    validate_email_config!()
    validate_security_config!()
  end

  defp validate_database_config! do
    unless System.get_env("DATABASE_URL") do
      raise "DATABASE_URL environment variable is required"
    end
  end

  defp validate_external_apis! do
    required_apis = ["OPENAI_API_KEY", "STRIPE_SECRET_KEY", "LINKEDIN_CLIENT_ID"]
    
    for api_key <- required_apis do
      unless System.get_env(api_key) do
        raise "#{api_key} environment variable is required"
      end
    end
  end

  defp validate_email_config! do
    required_email_vars = ["SMTP_HOST", "SMTP_USERNAME", "SMTP_PASSWORD"]
    
    for var <- required_email_vars do
      unless System.get_env(var) do
        raise "#{var} environment variable is required for email functionality"
      end
    end
  end

  defp validate_security_config! do
    unless System.get_env("SECRET_KEY_BASE") do
      raise "SECRET_KEY_BASE environment variable is required"
    end
    
    secret_key = System.get_env("SECRET_KEY_BASE")
    if String.length(secret_key) < 64 do
      raise "SECRET_KEY_BASE must be at least 64 characters long"
    end
  end
end
```

## Troubleshooting Configuration Issues

### Common Configuration Problems

1. **Database Connection Issues**
   - Check DATABASE_URL format
   - Verify database server is running
   - Confirm credentials are correct

2. **External API Failures**
   - Verify API keys are correct and active
   - Check API rate limits
   - Confirm network connectivity

3. **Email Delivery Issues**
   - Test SMTP credentials
   - Check firewall settings
   - Verify DNS configuration

4. **SSL Certificate Problems**
   - Check certificate expiration
   - Verify certificate chain
   - Confirm private key matches certificate

### Configuration Testing

```bash
# Test database connection
mix ecto.migrate

# Test external APIs
iex -S mix
> LinkedinAi.AI.OpenAIClient.test_connection()
> LinkedinAi.Social.LinkedInClient.test_connection()

# Test email configuration
> LinkedinAi.Mailer.deliver_now(test_email)

# Validate all configuration
> LinkedinAi.ConfigValidator.validate!()
```