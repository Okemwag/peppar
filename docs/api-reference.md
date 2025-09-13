# API Reference

This document provides comprehensive API documentation for the LinkedIn AI Platform.

## Table of Contents

- [Authentication](#authentication)
- [Rate Limiting](#rate-limiting)
- [Error Handling](#error-handling)
- [Content Generation API](#content-generation-api)
- [Profile Analysis API](#profile-analysis-api)
- [Analytics API](#analytics-api)
- [Subscription API](#subscription-api)
- [User Management API](#user-management-api)
- [Webhooks](#webhooks)
- [SDKs and Libraries](#sdks-and-libraries)

## Authentication

The LinkedIn AI Platform API uses Bearer token authentication. All API requests must include a valid authentication token in the Authorization header.

### Getting an API Token

1. Log in to your account
2. Navigate to **Settings** > **API Access**
3. Generate a new API token
4. Copy and securely store your token

### Authentication Header

```http
Authorization: Bearer your_api_token_here
```

### Token Management

- **Expiration**: Tokens expire after 90 days of inactivity
- **Rotation**: Tokens can be rotated without downtime
- **Scopes**: Tokens inherit user subscription permissions

## Rate Limiting

API requests are rate-limited based on your subscription plan:

### Rate Limits by Plan

#### Basic Plan
- **100 requests per hour**
- **1,000 requests per day**
- **Content Generation**: 10 requests per month

#### Pro Plan
- **1,000 requests per hour**
- **10,000 requests per day**
- **Content Generation**: Unlimited

### Rate Limit Headers

All API responses include rate limit information:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1640995200
X-RateLimit-Window: 3600
```

### Rate Limit Exceeded

When rate limits are exceeded, the API returns a `429 Too Many Requests` status:

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Try again in 3600 seconds.",
    "retry_after": 3600
  }
}
```

## Error Handling

The API uses conventional HTTP response codes and returns JSON error objects.

### HTTP Status Codes

- **200 OK**: Request successful
- **201 Created**: Resource created successfully
- **400 Bad Request**: Invalid request parameters
- **401 Unauthorized**: Invalid or missing authentication
- **403 Forbidden**: Insufficient permissions
- **404 Not Found**: Resource not found
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Server error

### Error Response Format

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "Additional error details"
    },
    "request_id": "req_1234567890"
  }
}
```

### Common Error Codes

- `INVALID_TOKEN`: Authentication token is invalid or expired
- `INSUFFICIENT_PERMISSIONS`: User lacks required permissions
- `VALIDATION_ERROR`: Request validation failed
- `RESOURCE_NOT_FOUND`: Requested resource doesn't exist
- `RATE_LIMIT_EXCEEDED`: API rate limit exceeded
- `SUBSCRIPTION_REQUIRED`: Feature requires active subscription
- `USAGE_LIMIT_EXCEEDED`: Monthly usage limit reached

## Content Generation API

Generate AI-powered LinkedIn content using OpenAI's GPT models.

### Generate Content

Create AI-generated LinkedIn content based on provided parameters.

```http
POST /api/v1/content/generate
```

#### Request Body

```json
{
  "content_type": "post",
  "topic": "artificial intelligence in healthcare",
  "tone": "professional",
  "length": "medium",
  "include_hashtags": true,
  "target_audience": "healthcare professionals",
  "call_to_action": true,
  "context": {
    "industry": "healthcare",
    "role": "data scientist",
    "company": "HealthTech Solutions"
  }
}
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `content_type` | string | Yes | Type of content: `post`, `comment`, `message`, `headline` |
| `topic` | string | Yes | Main topic or subject for the content |
| `tone` | string | No | Tone of voice: `professional`, `casual`, `authoritative`, `friendly` |
| `length` | string | No | Content length: `short`, `medium`, `long` |
| `include_hashtags` | boolean | No | Whether to include relevant hashtags |
| `target_audience` | string | No | Intended audience for the content |
| `call_to_action` | boolean | No | Whether to include a call-to-action |
| `context` | object | No | Additional context about user's background |

#### Response

```json
{
  "id": "content_1234567890",
  "content_type": "post",
  "variations": [
    {
      "id": "var_001",
      "text": "Artificial Intelligence is revolutionizing healthcare by enabling faster diagnosis and personalized treatment plans. As a data scientist at HealthTech Solutions, I've seen firsthand how AI can analyze medical images with 95% accuracy, reducing diagnosis time from hours to minutes.\n\nKey benefits I've observed:\n• Improved diagnostic accuracy\n• Reduced healthcare costs\n• Enhanced patient outcomes\n• Streamlined workflows\n\nWhat AI applications in healthcare excite you the most? Share your thoughts below! 👇\n\n#ArtificialIntelligence #Healthcare #DataScience #MedTech #Innovation",
      "hashtags": ["#ArtificialIntelligence", "#Healthcare", "#DataScience", "#MedTech", "#Innovation"],
      "word_count": 89,
      "estimated_engagement": "high"
    }
  ],
  "usage": {
    "tokens_used": 150,
    "monthly_usage": 5,
    "monthly_limit": 10
  },
  "created_at": "2023-12-01T10:30:00Z"
}
```

### List Generated Content

Retrieve a list of previously generated content.

```http
GET /api/v1/content
```

#### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `limit` | integer | Number of items to return (max 100) |
| `offset` | integer | Number of items to skip |
| `content_type` | string | Filter by content type |
| `date_from` | string | Filter from date (ISO 8601) |
| `date_to` | string | Filter to date (ISO 8601) |
| `favorites_only` | boolean | Return only favorited content |

#### Response

```json
{
  "data": [
    {
      "id": "content_1234567890",
      "content_type": "post",
      "topic": "artificial intelligence in healthcare",
      "final_text": "AI is transforming healthcare...",
      "is_favorite": true,
      "engagement_metrics": {
        "likes": 45,
        "comments": 12,
        "shares": 8
      },
      "created_at": "2023-12-01T10:30:00Z"
    }
  ],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0,
    "has_more": true
  }
}
```

### Get Content Details

Retrieve details for a specific piece of generated content.

```http
GET /api/v1/content/{content_id}
```

#### Response

```json
{
  "id": "content_1234567890",
  "content_type": "post",
  "topic": "artificial intelligence in healthcare",
  "original_prompt": "Write a LinkedIn post about AI in healthcare",
  "variations": [
    {
      "id": "var_001",
      "text": "AI is revolutionizing healthcare...",
      "selected": true
    }
  ],
  "final_text": "AI is revolutionizing healthcare...",
  "hashtags": ["#AI", "#Healthcare"],
  "is_favorite": true,
  "linkedin_post_id": "urn:li:activity:1234567890",
  "engagement_metrics": {
    "likes": 45,
    "comments": 12,
    "shares": 8,
    "click_through_rate": 0.05
  },
  "created_at": "2023-12-01T10:30:00Z",
  "updated_at": "2023-12-01T11:00:00Z"
}
```

### Update Content

Update generated content (mark as favorite, edit text, etc.).

```http
PUT /api/v1/content/{content_id}
```

#### Request Body

```json
{
  "final_text": "Updated content text...",
  "is_favorite": true,
  "hashtags": ["#AI", "#Healthcare", "#Innovation"]
}
```

### Delete Content

Delete generated content from your library.

```http
DELETE /api/v1/content/{content_id}
```

## Profile Analysis API

Analyze and optimize LinkedIn profiles using AI-powered insights.

### Analyze Profile

Run a comprehensive analysis of a LinkedIn profile.

```http
POST /api/v1/profile/analyze
```

#### Request Body

```json
{
  "profile_url": "https://linkedin.com/in/username",
  "analysis_type": "comprehensive",
  "include_competitors": true,
  "target_keywords": ["data science", "machine learning", "AI"]
}
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `profile_url` | string | No | LinkedIn profile URL (uses connected profile if not provided) |
| `analysis_type` | string | No | Analysis depth: `basic`, `comprehensive` |
| `include_competitors` | boolean | No | Include competitor comparison (Pro only) |
| `target_keywords` | array | No | Keywords to optimize for |

#### Response

```json
{
  "id": "analysis_1234567890",
  "profile_url": "https://linkedin.com/in/username",
  "analysis_type": "comprehensive",
  "overall_score": 78,
  "scores": {
    "headline": 85,
    "summary": 72,
    "experience": 80,
    "skills": 75,
    "keywords": 70
  },
  "improvements": [
    {
      "section": "headline",
      "priority": "high",
      "current": "Data Scientist at TechCorp",
      "suggested": "Senior Data Scientist | AI/ML Expert | Transforming Healthcare with Data-Driven Solutions",
      "impact": "Could increase profile views by 25%",
      "keywords_added": ["AI/ML", "Healthcare", "Data-Driven"]
    }
  ],
  "keyword_analysis": {
    "current_keywords": ["data science", "python", "machine learning"],
    "missing_keywords": ["artificial intelligence", "deep learning", "NLP"],
    "keyword_density": 0.12
  },
  "competitor_comparison": {
    "average_score": 72,
    "top_performer_score": 92,
    "your_ranking": "top 25%"
  },
  "created_at": "2023-12-01T10:30:00Z"
}
```

### List Profile Analyses

Retrieve historical profile analyses.

```http
GET /api/v1/profile/analyses
```

#### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `limit` | integer | Number of items to return |
| `offset` | integer | Number of items to skip |
| `date_from` | string | Filter from date |
| `date_to` | string | Filter to date |

### Get Analysis Details

Retrieve details for a specific profile analysis.

```http
GET /api/v1/profile/analyses/{analysis_id}
```

### Track Improvements

Track implementation of profile improvement suggestions.

```http
POST /api/v1/profile/improvements
```

#### Request Body

```json
{
  "analysis_id": "analysis_1234567890",
  "implemented_suggestions": [
    {
      "suggestion_id": "sugg_001",
      "implemented": true,
      "implementation_date": "2023-12-02T09:00:00Z",
      "notes": "Updated headline as suggested"
    }
  ]
}
```

## Analytics API

Access performance analytics and insights for your LinkedIn activities.

### Get Dashboard Metrics

Retrieve key metrics for the dashboard overview.

```http
GET /api/v1/analytics/dashboard
```

#### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `period` | string | Time period: `7d`, `30d`, `90d`, `1y` |
| `timezone` | string | Timezone for date calculations |

#### Response

```json
{
  "period": "30d",
  "metrics": {
    "content_generated": {
      "current": 8,
      "previous": 5,
      "change_percent": 60
    },
    "profile_score": {
      "current": 78,
      "previous": 72,
      "change_percent": 8.3
    },
    "profile_views": {
      "current": 245,
      "previous": 189,
      "change_percent": 29.6
    },
    "engagement_rate": {
      "current": 0.045,
      "previous": 0.032,
      "change_percent": 40.6
    }
  },
  "charts": {
    "profile_views": [
      {"date": "2023-11-01", "value": 8},
      {"date": "2023-11-02", "value": 12}
    ],
    "content_engagement": [
      {"date": "2023-11-01", "likes": 15, "comments": 3, "shares": 2}
    ]
  }
}
```

### Get Content Analytics

Retrieve detailed analytics for content performance.

```http
GET /api/v1/analytics/content
```

#### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `content_id` | string | Specific content ID |
| `period` | string | Time period for analysis |
| `metrics` | string | Comma-separated metrics to include |

#### Response

```json
{
  "content_performance": [
    {
      "content_id": "content_1234567890",
      "content_type": "post",
      "topic": "AI in healthcare",
      "published_date": "2023-11-15T09:00:00Z",
      "metrics": {
        "impressions": 1250,
        "likes": 45,
        "comments": 12,
        "shares": 8,
        "clicks": 23,
        "engagement_rate": 0.07
      },
      "performance_score": 85
    }
  ],
  "summary": {
    "total_impressions": 15000,
    "average_engagement_rate": 0.055,
    "best_performing_type": "thought_leadership",
    "optimal_posting_time": "09:00"
  }
}
```

### Get Profile Analytics

Retrieve analytics for profile performance and optimization.

```http
GET /api/v1/analytics/profile
```

#### Response

```json
{
  "profile_metrics": {
    "views": {
      "current_period": 245,
      "previous_period": 189,
      "trend": "increasing"
    },
    "search_appearances": {
      "current_period": 89,
      "previous_period": 67,
      "trend": "increasing"
    },
    "connection_requests": {
      "received": 23,
      "sent": 15,
      "acceptance_rate": 0.78
    }
  },
  "optimization_progress": {
    "overall_score": 78,
    "score_history": [
      {"date": "2023-11-01", "score": 72},
      {"date": "2023-12-01", "score": 78}
    ],
    "improvements_implemented": 5,
    "pending_improvements": 3
  }
}
```

### Export Analytics

Export analytics data in various formats.

```http
POST /api/v1/analytics/export
```

#### Request Body

```json
{
  "format": "pdf",
  "report_type": "comprehensive",
  "period": "30d",
  "sections": ["overview", "content", "profile", "recommendations"],
  "email_delivery": true
}
```

#### Response

```json
{
  "export_id": "export_1234567890",
  "status": "processing",
  "estimated_completion": "2023-12-01T10:35:00Z",
  "download_url": null,
  "email_sent": false
}
```

## Subscription API

Manage subscription plans, billing, and usage tracking.

### Get Subscription Details

Retrieve current subscription information.

```http
GET /api/v1/subscription
```

#### Response

```json
{
  "id": "sub_1234567890",
  "plan": "pro",
  "status": "active",
  "current_period_start": "2023-11-01T00:00:00Z",
  "current_period_end": "2023-12-01T00:00:00Z",
  "cancel_at_period_end": false,
  "features": {
    "content_generation_limit": "unlimited",
    "profile_analysis": "advanced",
    "analytics_history_days": "unlimited",
    "competitor_analysis": true,
    "support_level": "priority"
  },
  "usage": {
    "content_generated_this_month": 25,
    "profile_analyses_this_month": 3,
    "api_calls_today": 150
  }
}
```

### Get Usage Statistics

Retrieve detailed usage statistics for the current billing period.

```http
GET /api/v1/subscription/usage
```

#### Query Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `period` | string | Usage period: `current`, `previous`, `all` |
| `breakdown` | string | Breakdown by: `day`, `week`, `month` |

#### Response

```json
{
  "period": "current",
  "usage_summary": {
    "content_generation": {
      "used": 25,
      "limit": "unlimited",
      "percentage": null
    },
    "profile_analyses": {
      "used": 3,
      "limit": "unlimited",
      "percentage": null
    },
    "api_calls": {
      "used": 4500,
      "limit": 10000,
      "percentage": 45
    }
  },
  "daily_breakdown": [
    {
      "date": "2023-11-01",
      "content_generation": 2,
      "profile_analyses": 0,
      "api_calls": 150
    }
  ]
}
```

### Create Checkout Session

Create a Stripe checkout session for subscription upgrade.

```http
POST /api/v1/subscription/checkout
```

#### Request Body

```json
{
  "plan": "pro",
  "success_url": "https://yourapp.com/success",
  "cancel_url": "https://yourapp.com/cancel"
}
```

#### Response

```json
{
  "checkout_session_id": "cs_1234567890",
  "checkout_url": "https://checkout.stripe.com/pay/cs_1234567890"
}
```

### Cancel Subscription

Cancel the current subscription (remains active until period end).

```http
POST /api/v1/subscription/cancel
```

#### Request Body

```json
{
  "reason": "switching_to_competitor",
  "feedback": "Need more advanced features"
}
```

## User Management API

Manage user account information and preferences.

### Get User Profile

Retrieve current user profile information.

```http
GET /api/v1/user/profile
```

#### Response

```json
{
  "id": "user_1234567890",
  "email": "user@example.com",
  "name": "John Doe",
  "role": "user",
  "linkedin_profile_url": "https://linkedin.com/in/johndoe",
  "linkedin_connected": true,
  "onboarding_completed": true,
  "preferences": {
    "email_notifications": true,
    "weekly_reports": true,
    "timezone": "America/New_York"
  },
  "created_at": "2023-10-01T10:00:00Z",
  "last_login": "2023-12-01T09:30:00Z"
}
```

### Update User Profile

Update user profile information and preferences.

```http
PUT /api/v1/user/profile
```

#### Request Body

```json
{
  "name": "John Doe",
  "preferences": {
    "email_notifications": false,
    "weekly_reports": true,
    "timezone": "America/Los_Angeles"
  }
}
```

### Connect LinkedIn Profile

Initiate LinkedIn profile connection flow.

```http
POST /api/v1/user/linkedin/connect
```

#### Response

```json
{
  "authorization_url": "https://linkedin.com/oauth/v2/authorization?...",
  "state": "random_state_string"
}
```

### Disconnect LinkedIn Profile

Disconnect the linked LinkedIn profile.

```http
DELETE /api/v1/user/linkedin/disconnect
```

## Webhooks

The LinkedIn AI Platform can send webhooks to notify your application of important events.

### Webhook Events

#### Subscription Events
- `subscription.created`: New subscription activated
- `subscription.updated`: Subscription plan changed
- `subscription.cancelled`: Subscription cancelled
- `subscription.payment_failed`: Payment failed

#### Content Events
- `content.generated`: New content generated
- `content.published`: Content published to LinkedIn
- `content.engagement_updated`: Engagement metrics updated

#### Profile Events
- `profile.analyzed`: Profile analysis completed
- `profile.score_updated`: Profile score changed
- `profile.improvement_implemented`: Improvement suggestion implemented

### Webhook Payload Format

```json
{
  "id": "evt_1234567890",
  "type": "subscription.created",
  "created": 1640995200,
  "data": {
    "object": {
      "id": "sub_1234567890",
      "user_id": "user_1234567890",
      "plan": "pro",
      "status": "active"
    }
  }
}
```

### Webhook Security

Webhooks are signed using HMAC SHA-256. Verify the signature using the webhook secret:

```python
import hmac
import hashlib

def verify_webhook(payload, signature, secret):
    expected_signature = hmac.new(
        secret.encode('utf-8'),
        payload.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, expected_signature)
```

## SDKs and Libraries

### Official SDKs

#### JavaScript/Node.js
```bash
npm install @linkedin-ai/sdk
```

```javascript
const LinkedInAI = require('@linkedin-ai/sdk');

const client = new LinkedInAI({
  apiKey: 'your_api_token'
});

// Generate content
const content = await client.content.generate({
  content_type: 'post',
  topic: 'artificial intelligence',
  tone: 'professional'
});
```

#### Python
```bash
pip install linkedin-ai-sdk
```

```python
from linkedin_ai import LinkedInAIClient

client = LinkedInAIClient(api_key='your_api_token')

# Generate content
content = client.content.generate(
    content_type='post',
    topic='artificial intelligence',
    tone='professional'
)
```

#### PHP
```bash
composer require linkedin-ai/sdk
```

```php
use LinkedInAI\Client;

$client = new Client('your_api_token');

// Generate content
$content = $client->content()->generate([
    'content_type' => 'post',
    'topic' => 'artificial intelligence',
    'tone' => 'professional'
]);
```

### Community Libraries

- **Ruby**: `linkedin_ai_ruby` gem
- **Go**: `linkedin-ai-go` package
- **Java**: `linkedin-ai-java` library
- **.NET**: `LinkedInAI.NET` NuGet package

## API Versioning

The LinkedIn AI Platform API uses URL-based versioning. The current version is `v1`.

### Version Format
```
https://api.linkedin-ai-platform.com/api/v1/
```

### Deprecation Policy

- **Advance Notice**: 6 months notice before deprecation
- **Support Period**: Deprecated versions supported for 12 months
- **Migration Guide**: Detailed migration guides provided
- **Backward Compatibility**: Maintained within major versions

### Version History

- **v1.0** (Current): Initial API release
- **v1.1** (Planned): Enhanced analytics endpoints
- **v2.0** (Future): GraphQL support, improved rate limiting

## Support and Resources

### Getting Help

- **API Documentation**: This document
- **Interactive API Explorer**: Available in your dashboard
- **Support Email**: api-support@linkedin-ai-platform.com
- **Community Forum**: https://community.linkedin-ai-platform.com
- **Status Page**: https://status.linkedin-ai-platform.com

### Best Practices

1. **Use HTTPS**: Always use HTTPS for API requests
2. **Handle Rate Limits**: Implement exponential backoff
3. **Validate Webhooks**: Always verify webhook signatures
4. **Cache Responses**: Cache responses when appropriate
5. **Error Handling**: Implement comprehensive error handling
6. **Monitor Usage**: Track your API usage and limits

### Terms of Service

By using the LinkedIn AI Platform API, you agree to our:
- [Terms of Service](https://linkedin-ai-platform.com/terms)
- [Privacy Policy](https://linkedin-ai-platform.com/privacy)
- [API Terms](https://linkedin-ai-platform.com/api-terms)