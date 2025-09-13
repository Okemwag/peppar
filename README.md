# LinkedIn AI Enhancement Platform

A comprehensive SaaS platform that helps professionals optimize their LinkedIn presence through AI-powered content generation, profile optimization, and engagement analytics. Built with Phoenix LiveView, the platform features a beautiful, animated user interface with subscription-based pricing tiers and a comprehensive admin panel.

## 🚀 Features

### AI-Powered Content Generation
- Generate high-quality LinkedIn posts, comments, and messages using OpenAI GPT-4
- Multiple content types: professional updates, industry insights, personal stories, engagement posts
- Smart hashtag suggestions and call-to-action recommendations
- Content editing and preview capabilities
- Content history and favorites management

### Profile Optimization Tools
- AI-powered LinkedIn profile analysis
- Specific improvement suggestions with before/after examples
- Industry-specific keyword recommendations
- Profile performance tracking over time
- Competitor comparison (Pro tier)

### Subscription Management
- **Basic Plan ($25/month)**: 10 AI-generated posts, basic profile analysis, 30-day analytics
- **Pro Plan ($45/month)**: Unlimited content generation, advanced analytics, competitor insights
- Secure Stripe payment processing
- Subscription lifecycle management
- Usage tracking and limits enforcement

### Beautiful User Interface
- Modern, animated interface built with Phoenix LiveView and Tailwind CSS
- Smooth page transitions and micro-animations
- Responsive design for desktop, tablet, and mobile
- Real-time updates and interactive dashboards
- Elegant loading states and error handling

### Analytics & Reporting
- Content performance metrics and engagement tracking
- Profile improvement analytics
- Export capabilities (PDF, CSV)
- Advanced insights for Pro subscribers
- Real-time dashboard updates

### Admin Panel
- Comprehensive user management
- Subscription and revenue analytics
- System health monitoring
- Content moderation tools
- Real-time metrics and reporting

## 🛠 Technology Stack

- **Backend**: Phoenix Framework 1.7+ with Elixir
- **Frontend**: Phoenix LiveView with Alpine.js
- **Database**: PostgreSQL with Ecto ORM
- **Styling**: Tailwind CSS with custom animations
- **Background Jobs**: Oban for async processing
- **External APIs**: OpenAI GPT-4, LinkedIn API, Stripe
- **Caching**: Redis for sessions and data caching
- **Deployment**: Docker with PostgreSQL
- **Monitoring**: Phoenix LiveDashboard, Telemetry

## 📋 Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- Node.js 18+ and npm
- PostgreSQL 14+
- Redis 6+ (for caching)
- Docker and Docker Compose (for development)

## 🚀 Quick Start

### Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd linkedin-ai-platform
   ```

2. **Install dependencies**
   ```bash
   mix setup
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys and configuration
   ```

4. **Start the development server**
   ```bash
   mix phx.server
   ```

5. **Visit the application**
   Open [http://localhost:4000](http://localhost:4000) in your browser

### Docker Development Setup

1. **Start with Docker Compose**
   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

2. **Run database migrations**
   ```bash
   docker-compose -f docker-compose.dev.yml exec web mix ecto.migrate
   ```

## ⚙️ Configuration

### Required Environment Variables

```bash
# Database
DATABASE_URL=postgresql://username:password@localhost/linkedin_ai_dev

# External APIs
OPENAI_API_KEY=your_openai_api_key
LINKEDIN_CLIENT_ID=your_linkedin_client_id
LINKEDIN_CLIENT_SECRET=your_linkedin_client_secret
STRIPE_PUBLIC_KEY=your_stripe_public_key
STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret

# Redis (optional, for caching)
REDIS_URL=redis://localhost:6379

# Application
SECRET_KEY_BASE=your_secret_key_base
PHX_HOST=localhost
PORT=4000
```

### Subscription Plans Configuration

The platform supports two subscription tiers:

- **Basic ($25/month)**:
  - 10 AI-generated posts per month
  - Basic profile analysis
  - 30-day analytics history
  
- **Pro ($45/month)**:
  - Unlimited content generation
  - Advanced profile analytics
  - Unlimited analytics history
  - Competitor comparison

## 🧪 Testing

### Run the test suite
```bash
mix test
```

### Run tests with coverage
```bash
mix test --cover
```

### Run integration tests
```bash
mix test --only integration
```

### Run performance tests
```bash
mix test --only performance
```

## 📚 API Documentation

Generate API documentation with ExDoc:

```bash
mix docs
```

View the generated documentation at `doc/index.html`.

### Key API Endpoints

- `POST /api/content/generate` - Generate AI content
- `GET /api/profile/analyze` - Analyze LinkedIn profile
- `POST /api/subscriptions/create` - Create subscription
- `GET /api/analytics/dashboard` - Get dashboard metrics

## 🚀 Deployment

### Production Deployment with Docker

1. **Build the production image**
   ```bash
   docker build -t linkedin-ai-platform .
   ```

2. **Run with Docker Compose**
   ```bash
   docker-compose up -d
   ```

3. **Run database migrations**
   ```bash
   docker-compose exec web mix ecto.migrate
   ```

### Environment-Specific Configuration

- **Development**: Uses local PostgreSQL and Redis
- **Staging**: Docker containers with external database
- **Production**: Fully containerized with health checks

### Health Checks

The application includes health check endpoints:

- `/health` - Basic application health
- `/health/db` - Database connectivity
- `/health/redis` - Redis connectivity
- `/health/external` - External API status

## 📊 Monitoring

### Application Monitoring

- Phoenix LiveDashboard available at `/dashboard`
- Telemetry metrics for performance monitoring
- Error tracking and logging
- Real-time system metrics

### Key Metrics

- User registration and subscription rates
- Content generation usage
- API response times
- Database query performance
- External API success rates

## 🔒 Security

### Security Features

- Secure authentication with bcrypt password hashing
- CSRF protection on all forms
- API key encryption for external services
- Rate limiting on API endpoints
- Secure session management
- PCI compliance through Stripe integration

### Data Protection

- Encryption at rest for sensitive data
- HTTPS enforcement in production
- LinkedIn API compliance
- GDPR compliance for EU users
- Regular security audits and updates

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Elixir and Phoenix best practices
- Write comprehensive tests for new features
- Update documentation for API changes
- Use conventional commit messages
- Ensure code passes all linting and formatting checks

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the `/docs` directory for detailed guides
- **Issues**: Report bugs and feature requests via GitHub Issues
- **Community**: Join our community discussions
- **Email**: Contact support at support@linkedin-ai-platform.com

## 🗺 Roadmap

### Upcoming Features

- [ ] Advanced analytics dashboard
- [ ] Team collaboration features
- [ ] LinkedIn automation tools
- [ ] Mobile application
- [ ] API rate limiting improvements
- [ ] Multi-language support

### Recent Updates

- ✅ AI-powered content generation
- ✅ Profile optimization tools
- ✅ Subscription management
- ✅ Admin panel
- ✅ Real-time analytics

---

Built with ❤️ using Phoenix LiveView and Elixir
