# Insurance Policy Manager - API Specification

## 1. Introduction

This document provides the specification for the RESTful APIs that support the Insurance Policy Manager mobile application. These APIs enable document management, information extraction, natural language querying, and other essential functionality for the application.

### 1.1 Purpose and Scope

This API specification defines:
- API endpoints and their functionality
- Request and response formats
- Authentication and authorization mechanisms
- Error handling approaches
- API versioning strategy
- Integration patterns with third-party services

This document serves as a reference for both API development and client integration, ensuring consistency and alignment between frontend and backend teams.

### 1.2 API Design Principles

The APIs follow these design principles:

1. **RESTful Design**: Resource-oriented with appropriate HTTP methods
2. **JSON Format**: Consistent JSON format for request/response bodies
3. **Statelessness**: No server-side session state between requests
4. **Versioning**: Clear versioning strategy to support evolution
5. **Security**: Comprehensive authentication and authorization
6. **Performance**: Optimized for mobile client needs
7. **Documentation**: Self-documenting with OpenAPI specifications
8. **Consistency**: Uniform patterns across all endpoints

### 1.3 API Environments

| Environment | Base URL | Purpose |
|-------------|----------|---------|
| Development | https://api-dev.insuranceapp.com/v1 | Development and integration testing |
| Staging | https://api-staging.insuranceapp.com/v1 | Pre-production validation |
| Production | https://api.insuranceapp.com/v1 | Production use |

## 2. Authentication and Authorization

### 2.1 Authentication Mechanism

The API uses JSON Web Tokens (JWT) for authentication:

1. **Access Token**: Short-lived token (15 minutes) for API access
2. **Refresh Token**: Longer-lived token (7 days) for obtaining new access tokens
3. **ID Token**: Contains user identity information

#### 2.1.1 Token Acquisition

**Endpoint**: `POST /auth/token`

**Request**:
```json
{
  "grant_type": "password",
  "username": "user@example.com",
  "password": "userPassword123"
}
```

**Response**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "id_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 900
}
```

#### 2.1.2 Token Refresh

**Endpoint**: `POST /auth/token`

**Request**:
```json
{
  "grant_type": "refresh_token",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response**: Same as token acquisition

#### 2.1.3 Token Usage

All protected API endpoints require the access token in the Authorization header:

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 2.2 Authorization Model

The API implements role-based access control (RBAC) with the following roles:

1. **User**: Standard application user
2. **Premium**: User with premium subscription features
3. **Admin**: Administrative access (internal use)

Permissions are enforced at the endpoint level based on the user's role as encoded in the JWT.

## 3. Common Patterns

### 3.1 Request Headers

All API requests should include:

```
Content-Type: application/json
Authorization: Bearer <access_token>
Accept-Language: en-US (optional)
X-Client-Version: 1.0.0 (app version)
X-Request-ID: <uuid> (for request tracking)
```

### 3.2 Response Format

All API responses follow a consistent structure:

**Success Response**:
```json
{
  "status": "success",
  "data": { ... },
  "meta": {
    "timestamp": "2023-05-10T15:32:10Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

**Error Response**:
```json
{
  "status": "error",
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "The requested resource was not found",
    "details": { ... }
  },
  "meta": {
    "timestamp": "2023-05-10T15:32:10Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 3.3 Pagination

List endpoints support pagination with the following parameters:

**Request**:
```
GET /resources?page=2&page_size=20&sort=created_at:desc
```

**Response**:
```json
{
  "status": "success",
  "data": [ ... ],
  "meta": {
    "pagination": {
      "page": 2,
      "page_size": 20,
      "total_pages": 10,
      "total_items": 195,
      "links": {
        "self": "/resources?page=2&page_size=20",
        "first": "/resources?page=1&page_size=20",
        "prev": "/resources?page=1&page_size=20",
        "next": "/resources?page=3&page_size=20",
        "last": "/resources?page=10&page_size=20"
      }
    },
    "timestamp": "2023-05-10T15:32:10Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 3.4 Filtering

List endpoints support filtering with query parameters:

```
GET /resources?status=active&created_after=2023-01-01T00:00:00Z
```

### 3.5 Error Codes

| Error Code | HTTP Status | Description |
|------------|-------------|-------------|
| AUTHENTICATION_FAILED | 401 | Invalid or expired credentials |
| AUTHORIZATION_FAILED | 403 | Insufficient permissions |
| RESOURCE_NOT_FOUND | 404 | Requested resource does not exist |
| VALIDATION_ERROR | 400 | Request failed validation checks |
| RATE_LIMIT_EXCEEDED | 429 | API rate limit exceeded |
| INTERNAL_ERROR | 500 | Unexpected server error |
| SERVICE_UNAVAILABLE | 503 | Service temporarily unavailable |

## 4. API Endpoints

### 4.1 User Management

#### 4.1.1 Create User Account

**Endpoint**: `POST /users`

**Request**:
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "name": "John Doe",
  "phone_number": "+12345678900",
  "notification_preferences": {
    "email": true,
    "push": true,
    "sms": false
  }
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2023-05-10T15:32:10Z",
    "notification_preferences": {
      "email": true,
      "push": true,
      "sms": false
    }
  },
  "meta": {
    "timestamp": "2023-05-10T15:32:10Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.1.2 Get User Profile

**Endpoint**: `GET /users/me`

**Response**:
```json
{
  "status": "success",
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Doe",
    "phone_number": "+12345678900",
    "notification_preferences": {
      "email": true,
      "push": true,
      "sms": false
    },
    "subscription_status": "free",
    "created_at": "2023-05-10T15:32:10Z",
    "last_login": "2023-05-10T15:32:10Z"
  },
  "meta": {
    "timestamp": "2023-05-10T15:32:10Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.1.3 Update User Profile

**Endpoint**: `PATCH /users/me`

**Request**:
```json
{
  "name": "John Smith",
  "phone_number": "+12345678901",
  "notification_preferences": {
    "sms": true
  }
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "John Smith",
    "phone_number": "+12345678901",
    "notification_preferences": {
      "email": true,
      "push": true,
      "sms": true
    },
    "updated_at": "2023-05-10T15:45:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T15:45:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 4.2 Document Management

#### 4.2.1 Document Upload

**Endpoint**: `POST /documents`

**Request**:
- Content-Type: multipart/form-data
- Form Fields:
  - document: File data
  - metadata: JSON string

```json
{
  "document_type": "health_insurance",
  "insurer": "Blue Cross",
  "nickname": "Family Health Plan 2023"
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "document_id": "550e8400-e29b-41d4-a716-446655440000",
    "original_filename": "health_policy.pdf",
    "upload_status": "success",
    "processing_status": "queued",
    "created_at": "2023-05-10T15:32:10Z",
    "document_type": "health_insurance",
    "insurer": "Blue Cross",
    "nickname": "Family Health Plan 2023",
    "estimated_processing_time": 60
  },
  "meta": {
    "timestamp": "2023-05-10T15:32:10Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.2.2 Get Document Processing Status

**Endpoint**: `GET /documents/{document_id}/status`

**Response**:
```json
{
  "status": "success",
  "data": {
    "document_id": "550e8400-e29b-41d4-a716-446655440000",
    "processing_status": "completed",
    "processing_progress": 100,
    "extraction_confidence": 0.92,
    "processing_started_at": "2023-05-10T15:32:15Z",
    "processing_completed_at": "2023-05-10T15:33:10Z",
    "extracted_metadata": {
      "policy_number": "POL-123456789",
      "effective_date": "2023-01-01",
      "expiration_date": "2023-12-31",
      "premium_amount": 500.00,
      "premium_frequency": "monthly"
    }
  },
  "meta": {
    "timestamp": "2023-05-10T15:35:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.2.3 List Documents

**Endpoint**: `GET /documents?page=1&page_size=20&sort=created_at:desc&document_type=health_insurance`

**Response**:
```json
{
  "status": "success",
  "data": [
    {
      "document_id": "550e8400-e29b-41d4-a716-446655440000",
      "nickname": "Family Health Plan 2023",
      "document_type": "health_insurance",
      "insurer": "Blue Cross",
      "created_at": "2023-05-10T15:32:10Z",
      "processing_status": "completed",
      "extracted_metadata": {
        "policy_number": "POL-123456789",
        "effective_date": "2023-01-01",
        "expiration_date": "2023-12-31"
      },
      "thumbnail_url": "https://storage.insuranceapp.com/thumbnails/550e8400.jpg"
    },
    {
      "document_id": "550e8400-e29b-41d4-a716-446655440001",
      "nickname": "Auto Insurance 2023",
      "document_type": "auto_insurance",
      "insurer": "State Farm",
      "created_at": "2023-05-09T12:10:33Z",
      "processing_status": "completed",
      "extracted_metadata": {
        "policy_number": "AUTO-987654321",
        "effective_date": "2023-02-15",
        "expiration_date": "2024-02-14"
      },
      "thumbnail_url": "https://storage.insuranceapp.com/thumbnails/550e8401.jpg"
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total_pages": 1,
      "total_items": 2
    },
    "timestamp": "2023-05-10T15:40:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.2.4 Get Document Details

**Endpoint**: `GET /documents/{document_id}`

**Response**:
```json
{
  "status": "success",
  "data": {
    "document_id": "550e8400-e29b-41d4-a716-446655440000",
    "original_filename": "health_policy.pdf",
    "document_type": "health_insurance",
    "insurer": "Blue Cross",
    "nickname": "Family Health Plan 2023",
    "created_at": "2023-05-10T15:32:10Z",
    "processing_status": "completed",
    "extraction_confidence": 0.92,
    "file_size": 2456789,
    "page_count": 12,
    "document_url": "https://storage.insuranceapp.com/documents/550e8400.pdf",
    "thumbnail_url": "https://storage.insuranceapp.com/thumbnails/550e8400.jpg",
    "extracted_metadata": {
      "policy_number": "POL-123456789",
      "effective_date": "2023-01-01",
      "expiration_date": "2023-12-31",
      "policyholder": "John Smith",
      "premium_amount": 500.00,
      "premium_frequency": "monthly",
      "coverage_type": "family"
    },
    "extracted_coverage": [
      {
        "coverage_type": "hospital",
        "coverage_limit": "100% after deductible",
        "deductible": 1000.00,
        "copay": null,
        "coinsurance": 0.20,
        "notes": "Prior authorization required for non-emergency admission"
      },
      {
        "coverage_type": "prescription_drugs",
        "coverage_limit": "Tier-based coverage",
        "deductible": 200.00,
        "copay": {
          "tier1": 10.00,
          "tier2": 35.00,
          "tier3": 60.00
        },
        "coinsurance": null,
        "notes": "Mail order available for maintenance medications"
      }
    ],
    "extracted_exclusions": [
      "Cosmetic procedures",
      "Experimental treatments",
      "Weight loss programs",
      "Elective procedures not medically necessary"
    ]
  },
  "meta": {
    "timestamp": "2023-05-10T15:40:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.2.5 Get Document Original

**Endpoint**: `GET /documents/{document_id}/original`

**Response**:
- Content-Type: application/pdf
- Body: Binary PDF document data

#### 4.2.6 Update Document Metadata

**Endpoint**: `PATCH /documents/{document_id}`

**Request**:
```json
{
  "nickname": "Updated Health Plan Name",
  "insurer": "Blue Cross Blue Shield",
  "document_type": "health_insurance"
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "document_id": "550e8400-e29b-41d4-a716-446655440000",
    "nickname": "Updated Health Plan Name",
    "insurer": "Blue Cross Blue Shield",
    "document_type": "health_insurance",
    "updated_at": "2023-05-10T16:05:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T16:05:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.2.7 Delete Document

**Endpoint**: `DELETE /documents/{document_id}`

**Response**:
```json
{
  "status": "success",
  "data": {
    "document_id": "550e8400-e29b-41d4-a716-446655440000",
    "deleted_at": "2023-05-10T16:10:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T16:10:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 4.3 Policy Data APIs

#### 4.3.1 Get Policy Information

**Endpoint**: `GET /policies/{policy_id}`

**Response**:
```json
{
  "status": "success",
  "data": {
    "policy_id": "550e8400-e29b-41d4-a716-446655440000",
    "document_id": "550e8400-e29b-41d4-a716-446655440000",
    "policy_number": "POL-123456789",
    "policy_type": "health_insurance",
    "insurer": {
      "name": "Blue Cross Blue Shield",
      "contact": {
        "phone": "1-800-123-4567",
        "website": "https://www.bcbs.com",
        "email": "support@bcbs.com"
      }
    },
    "period": {
      "effective_date": "2023-01-01",
      "expiration_date": "2023-12-31"
    },
    "policyholder": {
      "name": "John Smith",
      "relationship": "self"
    },
    "covered_individuals": [
      {
        "name": "John Smith",
        "relationship": "self",
        "dob": "1980-05-15"
      },
      {
        "name": "Jane Smith",
        "relationship": "spouse",
        "dob": "1982-08-20"
      }
    ],
    "coverage_summary": {
      "type": "PPO",
      "network": "BlueChoice Network",
      "deductible": {
        "individual": {
          "in_network": 1000.00,
          "out_of_network": 2000.00
        },
        "family": {
          "in_network": 3000.00,
          "out_of_network": 6000.00
        }
      },
      "out_of_pocket_max": {
        "individual": {
          "in_network": 5000.00,
          "out_of_network": 10000.00
        },
        "family": {
          "in_network": 10000.00,
          "out_of_network": 20000.00
        }
      }
    },
    "premium": {
      "amount": 500.00,
      "frequency": "monthly",
      "due_date": "1st of month",
      "payment_method": "auto_pay"
    },
    "created_at": "2023-05-10T15:32:10Z",
    "updated_at": "2023-05-10T15:33:10Z",
    "extraction_confidence": 0.92
  },
  "meta": {
    "timestamp": "2023-05-10T16:15:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.3.2 Get Policy Coverage Details

**Endpoint**: `GET /policies/{policy_id}/coverage`

**Response**:
```json
{
  "status": "success",
  "data": {
    "policy_id": "550e8400-e29b-41d4-a716-446655440000",
    "coverage_details": [
      {
        "category": "physician_services",
        "sub_category": "primary_care",
        "in_network": {
          "coverage_type": "copay",
          "copay_amount": 25.00,
          "coinsurance_percentage": null,
          "deductible_applies": false,
          "coverage_limit": "unlimited",
          "notes": "Annual wellness visit covered at 100%"
        },
        "out_of_network": {
          "coverage_type": "coinsurance",
          "copay_amount": null,
          "coinsurance_percentage": 40,
          "deductible_applies": true,
          "coverage_limit": "reasonable and customary fees",
          "notes": null
        }
      },
      {
        "category": "physician_services",
        "sub_category": "specialist",
        "in_network": {
          "coverage_type": "copay",
          "copay_amount": 45.00,
          "coinsurance_percentage": null,
          "deductible_applies": false,
          "coverage_limit": "unlimited",
          "notes": null
        },
        "out_of_network": {
          "coverage_type": "coinsurance",
          "copay_amount": null,
          "coinsurance_percentage": 40,
          "deductible_applies": true,
          "coverage_limit": "reasonable and customary fees",
          "notes": null
        }
      },
      {
        "category": "hospital_services",
        "sub_category": "inpatient",
        "in_network": {
          "coverage_type": "coinsurance",
          "copay_amount": null,
          "coinsurance_percentage": 20,
          "deductible_applies": true,
          "coverage_limit": "unlimited",
          "notes": "Prior authorization required"
        },
        "out_of_network": {
          "coverage_type": "coinsurance",
          "copay_amount": null,
          "coinsurance_percentage": 40,
          "deductible_applies": true,
          "coverage_limit": "maximum 30 days per year",
          "notes": "Prior authorization required"
        }
      }
    ],
    "extraction_confidence": 0.89
  },
  "meta": {
    "timestamp": "2023-05-10T16:20:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.3.3 Get Policy Exclusions

**Endpoint**: `GET /policies/{policy_id}/exclusions`

**Response**:
```json
{
  "status": "success",
  "data": {
    "policy_id": "550e8400-e29b-41d4-a716-446655440000",
    "exclusions": [
      {
        "category": "cosmetic",
        "description": "Cosmetic procedures unless medically necessary",
        "exceptions": "Reconstructive surgery following mastectomy or due to birth defects",
        "source_section": "Exclusions and Limitations, Page 24"
      },
      {
        "category": "experimental",
        "description": "Experimental or investigational treatments and procedures",
        "exceptions": "Clinical trials that meet specific criteria",
        "source_section": "Exclusions and Limitations, Page 24-25"
      },
      {
        "category": "alternative_medicine",
        "description": "Alternative medicine including acupuncture, homeopathy",
        "exceptions": "Chiropractic care with prior authorization",
        "source_section": "Exclusions and Limitations, Page 25"
      }
    ],
    "general_limitations": [
      "Pre-existing conditions waiting period of 6 months",
      "Out-of-network services limited to reasonable and customary charges",
      "Referral required for specialist visits"
    ],
    "extraction_confidence": 0.85
  },
  "meta": {
    "timestamp": "2023-05-10T16:25:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.3.4 Update Policy Information

**Endpoint**: `PATCH /policies/{policy_id}`

**Request**:
```json
{
  "premium": {
    "amount": 525.00
  },
  "period": {
    "expiration_date": "2024-01-31"
  },
  "corrected_fields": [
    "premium.amount",
    "period.expiration_date"
  ]
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "policy_id": "550e8400-e29b-41d4-a716-446655440000",
    "premium": {
      "amount": 525.00,
      "frequency": "monthly",
      "due_date": "1st of month",
      "payment_method": "auto_pay"
    },
    "period": {
      "effective_date": "2023-01-01",
      "expiration_date": "2024-01-31"
    },
    "updated_at": "2023-05-10T16:30:22Z",
    "user_corrected": true
  },
  "meta": {
    "timestamp": "2023-05-10T16:30:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 4.4 Natural Language Query API

#### 4.4.1 Ask a Question

**Endpoint**: `POST /questions`

**Request**:
```json
{
  "query": "What is my deductible for hospital stays?",
  "policy_ids": ["550e8400-e29b-41d4-a716-446655440000"],
  "conversation_id": null
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "question_id": "550e8400-e29b-41d4-a716-446655440123",
    "conversation_id": "550e8400-e29b-41d4-a716-446655440789",
    "query": "What is my deductible for hospital stays?",
    "answer": "For hospital stays, your policy has an in-network deductible of $1,000 for an individual or $3,000 for family coverage. For out-of-network hospital stays, the deductible is $2,000 for an individual or $6,000 for family coverage. After meeting your deductible, you'll be responsible for 20% coinsurance for in-network stays or 40% coinsurance for out-of-network stays.",
    "confidence_score": 0.92,
    "policy_references": [
      {
        "policy_id": "550e8400-e29b-41d4-a716-446655440000",
        "policy_number": "POL-123456789",
        "policy_nickname": "Family Health Plan 2023",
        "document_references": [
          {
            "document_id": "550e8400-e29b-41d4-a716-446655440000",
            "page_number": 15,
            "section": "Hospital Services",
            "text_excerpt": "In-network hospital stays: Subject to annual deductible ($1,000 individual/$3,000 family), then 20% coinsurance."
          },
          {
            "document_id": "550e8400-e29b-41d4-a716-446655440000",
            "page_number": 15,
            "section": "Hospital Services",
            "text_excerpt": "Out-of-network hospital stays: Subject to annual out-of-network deductible ($2,000 individual/$6,000 family), then 40% coinsurance."
          }
        ]
      }
    ],
    "suggested_follow_up_questions": [
      "What is the maximum out-of-pocket expense for hospital stays?",
      "Do I need prior authorization for hospital admission?",
      "What is covered under hospital services?"
    ],
    "created_at": "2023-05-10T16:35:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T16:35:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.4.2 Get Conversation History

**Endpoint**: `GET /conversations/{conversation_id}`

**Response**:
```json
{
  "status": "success",
  "data": {
    "conversation_id": "550e8400-e29b-41d4-a716-446655440789",
    "messages": [
      {
        "message_id": "550e8400-e29b-41d4-a716-446655440123",
        "role": "user",
        "content": "What is my deductible for hospital stays?",
        "created_at": "2023-05-10T16:35:22Z"
      },
      {
        "message_id": "550e8400-e29b-41d4-a716-446655440124",
        "role": "assistant",
        "content": "For hospital stays, your policy has an in-network deductible of $1,000 for an individual or $3,000 for family coverage. For out-of-network hospital stays, the deductible is $2,000 for an individual or $6,000 for family coverage. After meeting your deductible, you'll be responsible for 20% coinsurance for in-network stays or 40% coinsurance for out-of-network stays.",
        "confidence_score": 0.92,
        "policy_references": [
          {
            "policy_id": "550e8400-e29b-41d4-a716-446655440000",
            "page_number": 15,
            "section": "Hospital Services"
          }
        ],
        "created_at": "2023-05-10T16:35:25Z"
      },
      {
        "message_id": "550e8400-e29b-41d4-a716-446655440125",
        "role": "user",
        "content": "Do I need prior authorization?",
        "created_at": "2023-05-10T16:36:10Z"
      },
      {
        "message_id": "550e8400-e29b-41d4-a716-446655440126",
        "role": "assistant",
        "content": "Yes, your policy requires prior authorization for all non-emergency hospital admissions, both in-network and out-of-network. Failure to obtain prior authorization may result in a reduction of benefits or denial of coverage.",
        "confidence_score": 0.95,
        "policy_references": [
          {
            "policy_id": "550e8400-e29b-41d4-a716-446655440000",
            "page_number": 16,
            "section": "Prior Authorization Requirements"
          }
        ],
        "created_at": "2023-05-10T16:36:15Z"
      }
    ],
    "related_policies": [
      {
        "policy_id": "550e8400-e29b-41d4-a716-446655440000",
        "policy_number": "POL-123456789",
        "policy_nickname": "Family Health Plan 2023"
      }
    ],
    "created_at": "2023-05-10T16:35:22Z",
    "updated_at": "2023-05-10T16:36:15Z"
  },
  "meta": {
    "timestamp": "2023-05-10T16:40:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 4.5 Policy Comparison API

#### 4.5.1 Create Comparison

**Endpoint**: `POST /comparisons`

**Request**:
```json
{
  "policy_ids": [
    "550e8400-e29b-41d4-a716-446655440000",
    "550e8400-e29b-41d4-a716-446655440001"
  ],
  "comparison_type": "cross_policy"
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "comparison_id": "550e8400-e29b-41d4-a716-446655440999",
    "comparison_type": "cross_policy",
    "status": "processing",
    "policies": [
      {
        "policy_id": "550e8400-e29b-41d4-a716-446655440000",
        "policy_number": "POL-123456789",
        "policy_nickname": "Family Health Plan 2023",
        "insurer": "Blue Cross Blue Shield",
        "policy_type": "health_insurance"
      },
      {
        "policy_id": "550e8400-e29b-41d4-a716-446655440001",
        "policy_number": "POL-987654321",
        "policy_nickname": "Health Plan Quote",
        "insurer": "Aetna",
        "policy_type": "health_insurance"
      }
    ],
    "estimated_completion_time": "2023-05-10T16:42:22Z",
    "created_at": "2023-05-10T16:40:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T16:40:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.5.2 Get Comparison Results

**Endpoint**: `GET /comparisons/{comparison_id}`

**Response**:
```json
{
  "status": "success",
  "data": {
    "comparison_id": "550e8400-e29b-41d4-a716-446655440999",
    "comparison_type": "cross_policy",
    "status": "completed",
    "policies": [
      {
        "policy_id": "550e8400-e29b-41d4-a716-446655440000",
        "policy_number": "POL-123456789",
        "policy_nickname": "Family Health Plan 2023",
        "insurer": "Blue Cross Blue Shield",
        "policy_type": "health_insurance"
      },
      {
        "policy_id": "550e8400-e29b-41d4-a716-446655440001",
        "policy_number": "POL-987654321",
        "policy_nickname": "Health Plan Quote",
        "insurer": "Aetna",
        "policy_type": "health_insurance"
      }
    ],
    "summary": {
      "overall_comparison": "The BCBS plan has higher premiums but lower deductibles and out-of-pocket maximums. The Aetna plan offers better prescription coverage but has a more limited provider network.",
      "key_advantages": {
        "policy_1": [
          "Lower deductible ($1,000 vs $1,500)",
          "Larger provider network",
          "Lower coinsurance for hospital stays (20% vs 30%)"
        ],
        "policy_2": [
          "Lower premium ($450 vs $500 monthly)",
          "Better prescription coverage ($10/$30/$50 vs $15/$40/$75)",
          "Includes adult vision coverage"
        ]
      },
      "cost_comparison": {
        "annual_premium": {
          "policy_1": 6000.00,
          "policy_2": 5400.00,
          "difference": 600.00,
          "difference_percentage": 10.00
        },
        "deductible": {
          "policy_1": 1000.00,
          "policy_2": 1500.00,
          "difference": 500.00,
          "difference_percentage": 33.33
        },
        "out_of_pocket_max": {
          "policy_1": 5000.00,
          "policy_2": 6000.00,
          "difference": 1000.00,
          "difference_percentage": 16.67
        }
      }
    },
    "detailed_comparison": {
      "premium": {
        "policy_1": {
          "amount": 500.00,
          "frequency": "monthly"
        },
        "policy_2": {
          "amount": 450.00,
          "frequency": "monthly"
        }
      },
      "deductible": {
        "policy_1": {
          "individual_in_network": 1000.00,
          "family_in_network": 3000.00,
          "individual_out_of_network": 2000.00,
          "family_out_of_network": 6000.00
        },
        "policy_2": {
          "individual_in_network": 1500.00,
          "family_in_network": 4500.00,
          "individual_out_of_network": 3000.00,
          "family_out_of_network": 9000.00
        }
      },
      "coverage_categories": [
        {
          "category": "primary_care_visits",
          "policy_1": {
            "coverage_type": "copay",
            "in_network_amount": "$25 copay",
            "out_of_network_amount": "40% after deductible"
          },
          "policy_2": {
            "coverage_type": "copay",
            "in_network_amount": "$30 copay",
            "out_of_network_amount": "50% after deductible"
          }
        },
        {
          "category": "specialist_visits",
          "policy_1": {
            "coverage_type": "copay",
            "in_network_amount": "$45 copay",
            "out_of_network_amount": "40% after deductible"
          },
          "policy_2": {
            "coverage_type": "copay",
            "in_network_amount": "$50 copay",
            "out_of_network_amount": "50% after deductible"
          }
        },
        {
          "category": "hospital_stays",
          "policy_1": {
            "coverage_type": "coinsurance",
            "in_network_amount": "20% after deductible",
            "out_of_network_amount": "40% after deductible",
            "notes": "Prior authorization required"
          },
          "policy_2": {
            "coverage_type": "coinsurance",
            "in_network_amount": "30% after deductible",
            "out_of_network_amount": "50% after deductible",
            "notes": "Prior authorization required"
          }
        }
      ],
      "prescription_drugs": {
        "policy_1": {
          "structure": "3-tier formulary",
          "deductible": 200.00,
          "tier_1": "$15 copay",
          "tier_2": "$40 copay",
          "tier_3": "$75 copay",
          "specialty": "25% coinsurance",
          "mail_order": "90-day supply for 2 copays"
        },
        "policy_2": {
          "structure": "3-tier formulary",
          "deductible": 0.00,
          "tier_1": "$10 copay",
          "tier_2": "$30 copay",
          "tier_3": "$50 copay",
          "specialty": "30% coinsurance",
          "mail_order": "90-day supply for 2 copays"
        }
      },
      "additional_benefits": {
        "policy_1": [
          "Adult dental coverage $1,000 annual maximum",
          "Child vision and dental coverage",
          "24/7 nurse hotline",
          "Gym membership discount"
        ],
        "policy_2": [
          "Adult vision and dental coverage",
          "Child vision and dental coverage",
          "Telemedicine with $0 copay",
          "Alternative medicine coverage (limited)"
        ]
      },
      "network_comparison": {
        "policy_1": {
          "network_name": "BlueChoice Network",
          "network_size": "Extensive",
          "major_hospitals": ["Memorial Hospital", "University Medical Center", "Children's Hospital"],
          "restricted_access": false
        },
        "policy_2": {
          "network_name": "Aetna Select Network",
          "network_size": "Moderate",
          "major_hospitals": ["Memorial Hospital", "Community Hospital"],
          "restricted_access": true
        }
      }
    },
    "coverage_gaps": [
      {
        "category": "mental_health_outpatient",
        "policy_1": "30 visits per year",
        "policy_2": "Unlimited visits"
      },
      {
        "category": "infertility_treatment",
        "policy_1": "Covered with limitations",
        "policy_2": "Not covered"
      },
      {
        "category": "alternative_medicine",
        "policy_1": "Not covered",
        "policy_2": "Limited coverage for acupuncture and chiropractic"
      }
    ],
    "created_at": "2023-05-10T16:40:22Z",
    "completed_at": "2023-05-10T16:42:30Z"
  },
  "meta": {
    "timestamp": "2023-05-10T16:45:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 4.6 Notification Management

#### 4.6.1 Get User Notifications

**Endpoint**: `GET /notifications?page=1&page_size=20&status=unread`

**Response**:
```json
{
  "status": "success",
  "data": [
    {
      "notification_id": "550e8400-e29b-41d4-a716-446655440222",
      "type": "policy_expiration",
      "priority": "high",
      "title": "Policy Expiration Approaching",
      "message": "Your health insurance policy (POL-123456789) will expire in 30 days on December 31, 2023.",
      "policy_id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "unread",
      "action_url": "/policies/550e8400-e29b-41d4-a716-446655440000",
      "created_at": "2023-05-10T12:00:00Z"
    },
    {
      "notification_id": "550e8400-e29b-41d4-a716-446655440223",
      "type": "document_processed",
      "priority": "normal",
      "title": "Document Processing Complete",
      "message": "Your uploaded document 'Auto Insurance 2023' has been successfully processed.",
      "document_id": "550e8400-e29b-41d4-a716-446655440001",
      "status": "unread",
      "action_url": "/documents/550e8400-e29b-41d4-a716-446655440001",
      "created_at": "2023-05-09T15:30:00Z"
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total_pages": 1,
      "total_items": 2
    },
    "unread_count": 2,
    "timestamp": "2023-05-10T16:50:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.6.2 Update Notification Status

**Endpoint**: `PATCH /notifications/{notification_id}`

**Request**:
```json
{
  "status": "read"
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "notification_id": "550e8400-e29b-41d4-a716-446655440222",
    "status": "read",
    "updated_at": "2023-05-10T16:55:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T16:55:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.6.3 Configure Notification Settings

**Endpoint**: `PUT /users/me/notification-settings`

**Request**:
```json
{
  "channels": {
    "email": true,
    "push": true,
    "sms": false
  },
  "types": {
    "policy_expiration": {
      "enabled": true,
      "advance_notice_days": [30, 15, 7, 1]
    },
    "premium_due": {
      "enabled": true,
      "advance_notice_days": [7, 1]
    },
    "document_processing": {
      "enabled": true
    },
    "policy_updates": {
      "enabled": true
    }
  }
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "channels": {
      "email": true,
      "push": true,
      "sms": false
    },
    "types": {
      "policy_expiration": {
        "enabled": true,
        "advance_notice_days": [30, 15, 7, 1]
      },
      "premium_due": {
        "enabled": true,
        "advance_notice_days": [7, 1]
      },
      "document_processing": {
        "enabled": true
      },
      "policy_updates": {
        "enabled": true
      }
    },
    "updated_at": "2023-05-10T17:00:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T17:00:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 4.7 Device Management APIs

#### 4.7.1 Register Device

**Endpoint**: `POST /devices`

**Request**:
```json
{
  "device_token": "fcm-token-abc123",
  "device_type": "android",
  "app_version": "1.0.0",
  "os_version": "Android 12",
  "device_name": "Pixel 6",
  "timezone": "America/New_York"
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "device_id": "550e8400-e29b-41d4-a716-446655440333",
    "device_token": "fcm-token-abc123",
    "device_type": "android",
    "app_version": "1.0.0",
    "created_at": "2023-05-10T17:05:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T17:05:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.7.2 Update Device Token

**Endpoint**: `PUT /devices/{device_id}`

**Request**:
```json
{
  "device_token": "fcm-token-updated-xyz789",
  "app_version": "1.0.1"
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "device_id": "550e8400-e29b-41d4-a716-446655440333",
    "device_token": "fcm-token-updated-xyz789",
    "app_version": "1.0.1",
    "updated_at": "2023-05-10T17:10:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T17:10:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

#### 4.7.3 Delete Device

**Endpoint**: `DELETE /devices/{device_id}`

**Response**:
```json
{
  "status": "success",
  "data": {
    "device_id": "550e8400-e29b-41d4-a716-446655440333",
    "deleted_at": "2023-05-10T17:15:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T17:15:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

## 5. Versioning Strategy

### 5.1 API Versioning

The API uses URL-based versioning:

- **Current Version**: v1
- **Base URL**: https://api.insuranceapp.com/v1

When introducing breaking changes, a new version will be created:

- **Next Version**: v2
- **Base URL**: https://api.insuranceapp.com/v2

### 5.2 Version Lifecycle

1. **Active**: Current version, fully supported
2. **Deprecated**: Older version, still functional but migration recommended
3. **Sunset**: End-of-life announcement, with scheduled removal date
4. **Retired**: Version no longer available

### 5.3 Version Transition

When introducing a new API version:
1. Publish documentation and migration guide
2. Release new version alongside current version
3. Deprecation notice for old version
4. Minimum 6-month transition period before sunsetting

## 6. Rate Limiting

### 6.1 Rate Limit Structure

Rate limits are applied per API token:

| API Category | Limit | Time Window |
|--------------|-------|-------------|
| Authentication | 10 requests | 1 minute |
| Document Upload | 10 requests | 1 hour |
| Document Retrieval | 60 requests | 1 minute |
| Policy Data | 60 requests | 1 minute |
| Questions | 30 requests | 1 minute |
| General Endpoints | 120 requests | 1 minute |

### 6.2 Rate Limit Headers

Rate limit information is included in API responses:

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 58
X-RateLimit-Reset: 1683733800
```

### 6.3 Rate Limit Exceeded Response

When rate limit is exceeded:

```json
{
  "status": "error",
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Try again after reset time.",
    "details": {
      "limit": 60,
      "reset_at": "2023-05-10T17:30:00Z"
    }
  },
  "meta": {
    "timestamp": "2023-05-10T17:25:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

## 7. Webhooks (Future Implementation)

### 7.1 Webhook Subscription

**Endpoint**: `POST /webhooks`

**Request**:
```json
{
  "url": "https://example.com/webhook-handler",
  "events": ["document.processed", "policy.expiring_soon"],
  "secret": "whsec_abcdefghijklmnopqrstuvwxyz"
}
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "webhook_id": "550e8400-e29b-41d4-a716-446655440444",
    "url": "https://example.com/webhook-handler",
    "events": ["document.processed", "policy.expiring_soon"],
    "status": "active",
    "created_at": "2023-05-10T17:30:22Z"
  },
  "meta": {
    "timestamp": "2023-05-10T17:30:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 7.2 Webhook Event Format

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440555",
  "event": "document.processed",
  "created_at": "2023-05-10T17:35:22Z",
  "data": {
    "document_id": "550e8400-e29b-41d4-a716-446655440000",
    "processing_status": "completed",
    "processing_time": 65
  }
}
```

### 7.3 Webhook Security

- HTTPS required for webhook URLs
- Webhook requests include signature header for verification:
  ```
  X-Insurance-App-Signature: t=1683734122,v1=abcdefg123456...
  ```
- Signature is HMAC-SHA256 of payload using webhook secret

## 8. Error Handling

### 8.1 HTTP Status Codes

| Status Code | Meaning |
|-------------|---------|
| 200 | OK - Successful operation |
| 201 | Created - Resource successfully created |
| 202 | Accepted - Request accepted for processing |
| 400 | Bad Request - Invalid parameters or validation failure |
| 401 | Unauthorized - Missing or invalid authentication |
| 403 | Forbidden - Authenticated but insufficient permissions |
| 404 | Not Found - Resource not found |
| 409 | Conflict - Resource state conflict |
| 422 | Unprocessable Entity - Semantic errors in request |
| 429 | Too Many Requests - Rate limit exceeded |
| 500 | Internal Server Error - Unexpected server error |
| 503 | Service Unavailable - Temporary server unavailability |

### 8.2 Error Response Structure

```json
{
  "status": "error",
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "Error details for specific field",
      "additional_info": "Any additional error context"
    }
  },
  "meta": {
    "timestamp": "2023-05-10T17:40:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

### 8.3 Validation Errors

For validation errors, the details field contains field-specific error information:

```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid parameters",
    "details": {
      "fields": {
        "email": "Must be a valid email address",
        "password": "Must be at least 8 characters with 1 uppercase, 1 lowercase, and 1 number"
      }
    }
  },
  "meta": {
    "timestamp": "2023-05-10T17:45:22Z",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

## 9. Implementation Notes

### 9.1 API Development Technology

The API will be implemented using:
- **Framework**: FastAPI (Python)
- **Authentication**: JWT using Firebase Auth
- **Documentation**: OpenAPI/Swagger
- **Testing**: Pytest

### 9.2 API Documentation

The API will be documented using OpenAPI 3.0 specification, available at:
- https://api.insuranceapp.com/docs

Interactive documentation will be available at:
- https://api.insuranceapp.com/swagger

### 9.3 Client Libraries

Official client libraries will be provided for:
- Kotlin/Android
- Swift/iOS
- JavaScript/TypeScript
- Python

### 9.4 Implementation Phases

Phase 1:
- User management APIs
- Document upload and processing
- Basic policy data APIs
- Auth infrastructure

Phase 2:
- Natural language query APIs
- Policy comparison
- Notification system

Phase 3:
- Advanced analytics
- Webhooks
- Premium features
- Integration APIs

## Appendices

### Appendix A: OpenAPI Specification

[Link to OpenAPI JSON/YAML file]

### Appendix B: API Status Page

Service status and incidents will be tracked at https://status.insuranceapp.com

### Appendix C: Change Log

| Version | Date | Changes |
|---------|------|---------|
| v1.0.0 | 2023-05-01 | Initial API specification |
