# API Specification

This document provides a comprehensive specification for the Insurance Policy Parser & QA App's API, including endpoints, request/response formats, authentication, and error handling.

## API Overview

The Insurance Policy Parser & QA App API is a RESTful service that provides access to insurance policy management, document processing, and question answering capabilities. The API follows REST principles with JSON as the primary data exchange format.

### Base URL

```
https://api.example.com/v1
```

All API endpoints are relative to this base URL.

### Authentication

The API uses JWT (JSON Web Token) for authentication. All requests (except for public endpoints) must include the token in the Authorization header:

```
Authorization: Bearer <token>
```

#### Authentication Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /auth/login | Obtain JWT token with credentials |
| POST | /auth/register | Create a new user account |
| POST | /auth/refresh | Refresh an expired JWT token |
| POST | /auth/logout | Invalidate the current token |
| GET | /auth/profile | Get the current user's profile |

## API Endpoints

### Authentication

#### POST /auth/login

Authenticate a user and obtain a JWT token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "user123",
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2023-05-15T08:30:00Z"
  }
}
```

**Status Codes:**
- 200 OK: Successful authentication
- 400 Bad Request: Invalid request body
- 401 Unauthorized: Invalid credentials

#### POST /auth/register

Register a new user account.

**Request Body:**
```json
{
  "email": "newuser@example.com",
  "password": "securePassword123",
  "name": "Jane Smith"
}
```

**Response:**
```json
{
  "id": "user456",
  "email": "newuser@example.com",
  "name": "Jane Smith",
  "created_at": "2023-05-20T10:15:00Z"
}
```

**Status Codes:**
- 201 Created: Account created successfully
- 400 Bad Request: Invalid request or email already exists

#### POST /auth/refresh

Refresh an expired JWT token.

**Request Body:**
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Status Codes:**
- 200 OK: Token refreshed successfully
- 400 Bad Request: Invalid refresh token
- 401 Unauthorized: Expired refresh token

#### POST /auth/logout

Invalidate the current JWT token.

**Request:**
No request body required, just valid Authorization header.

**Response:**
```json
{
  "message": "Logged out successfully"
}
```

**Status Codes:**
- 200 OK: Logged out successfully
- 401 Unauthorized: Invalid token

#### GET /auth/profile

Get the current user's profile information.

**Request:**
No request body required, just valid Authorization header.

**Response:**
```json
{
  "id": "user123",
  "email": "user@example.com",
  "name": "John Doe",
  "created_at": "2023-05-15T08:30:00Z",
  "subscription": {
    "tier": "premium",
    "expires_at": "2024-05-15T08:30:00Z"
  },
  "preferences": {
    "notification_email": true,
    "notification_web": true,
    "theme": "light"
  }
}
```

**Status Codes:**
- 200 OK: Profile retrieved successfully
- 401 Unauthorized: Not authenticated

### Documents

#### POST /documents/upload

Upload insurance policy documents for processing.

**Request:**
Multipart form-data with files.

**Form Fields:**
- `files`: One or more PDF files
- `metadata` (optional): JSON string with document metadata

Example metadata:
```json
{
  "document_type": "health_insurance",
  "insurer": "Niva Bupa",
  "tags": ["health", "family"]
}
```

**Response:**
```json
{
  "documents": [
    {
      "id": "doc123",
      "filename": "policy_document.pdf",
      "size": 1258000,
      "upload_date": "2023-05-25T14:22:30Z",
      "status": "processing",
      "processing_id": "proc456"
    }
  ],
  "total_uploaded": 1,
  "total_failed": 0
}
```

**Status Codes:**
- 202 Accepted: Documents accepted for processing
- 400 Bad Request: Invalid files or metadata
- 401 Unauthorized: Not authenticated
- 413 Payload Too Large: Files exceed size limit

#### GET /documents

List all documents uploaded by the current user.

**Query Parameters:**
- `page` (optional): Page number for pagination
- `limit` (optional): Number of results per page
- `status` (optional): Filter by processing status
- `document_type` (optional): Filter by document type
- `sort` (optional): Sort by field, e.g. `upload_date:desc`

**Response:**
```json
{
  "documents": [
    {
      "id": "doc123",
      "filename": "policy_document.pdf",
      "size": 1258000,
      "upload_date": "2023-05-25T14:22:30Z",
      "status": "completed",
      "document_type": "health_insurance",
      "insurer": "Niva Bupa",
      "processing_completed_at": "2023-05-25T14:25:45Z"
    },
    {
      "id": "doc124",
      "filename": "auto_insurance.pdf",
      "size": 983000,
      "upload_date": "2023-05-26T09:10:15Z",
      "status": "processing",
      "document_type": "auto_insurance",
      "insurer": "Progressive"
    }
  ],
  "total": 24,
  "page": 1,
  "limit": 10,
  "total_pages": 3
}
```

**Status Codes:**
- 200 OK: Documents retrieved successfully
- 401 Unauthorized: Not authenticated

#### GET /documents/{document_id}

Get information about a specific document.

**Response:**
```json
{
  "id": "doc123",
  "filename": "policy_document.pdf",
  "original_path": "https://storage.example.com/documents/original/doc123.pdf",
  "processed_path": "https://storage.example.com/documents/processed/doc123.pdf",
  "size": 1258000,
  "upload_date": "2023-05-25T14:22:30Z",
  "status": "completed",
  "document_type": "health_insurance",
  "insurer": "Niva Bupa",
  "processing_started_at": "2023-05-25T14:22:35Z",
  "processing_completed_at": "2023-05-25T14:25:45Z",
  "processing_duration": 190,
  "pages": 24,
  "has_tables": true,
  "has_forms": true,
  "extraction_confidence": 0.92,
  "policy_id": "policy789"
}
```

**Status Codes:**
- 200 OK: Document retrieved successfully
- 401 Unauthorized: Not authenticated
- 403 Forbidden: Document belongs to another user
- 404 Not Found: Document not found

#### DELETE /documents/{document_id}

Delete a document and associated data.

**Response:**
```json
{
  "message": "Document deleted successfully",
  "id": "doc123"
}
```

**Status Codes:**
- 200 OK: Document deleted successfully
- 401 Unauthorized: Not authenticated
- 403 Forbidden: Document belongs to another user
- 404 Not Found: Document not found

#### GET /documents/{document_id}/status

Check the processing status of a document.

**Response:**
```json
{
  "id": "doc123",
  "status": "processing",
  "progress": 65,
  "stages": {
    "extraction": "completed",
    "ocr": "completed",
    "structure_analysis": "in_progress",
    "metadata_extraction": "pending",
    "indexing": "pending"
  },
  "estimated_completion_time": "2023-05-25T14:27:00Z",
  "errors": []
}
```

**Status Codes:**
- 200 OK: Status retrieved successfully
- 401 Unauthorized: Not authenticated
- 403 Forbidden: Document belongs to another user
- 404 Not Found: Document not found

### Policies

#### GET /policies

List all policies extracted from the user's documents.

**Query Parameters:**
- `page` (optional): Page number for pagination
- `limit` (optional): Number of results per page
- `policy_type` (optional): Filter by policy type
- `insurer` (optional): Filter by insurer
- `status` (optional): Filter by status (active, expired)
- `sort` (optional): Sort by field, e.g. `expiration_date:asc`

**Response:**
```json
{
  "policies": [
    {
      "id": "policy789",
      "policy_number": "HLT-1234567",
      "document_id": "doc123",
      "policy_type": "health_insurance",
      "insurer": "Niva Bupa",
      "effective_date": "2023-01-01",
      "expiration_date": "2024-01-01",
      "status": "active",
      "premium_amount": 12000,
      "premium_frequency": "annual",
      "insured_parties": ["John Doe", "Jane Doe"],
      "confidence_score": 0.94
    },
    {
      "id": "policy790",
      "policy_number": "AUTO-7654321",
      "document_id": "doc124",
      "policy_type": "auto_insurance",
      "insurer": "Progressive",
      "effective_date": "2023-03-15",
      "expiration_date": "2024-03-15",
      "status": "active",
      "premium_amount": 1200,
      "premium_frequency": "monthly",
      "insured_parties": ["John Doe"],
      "confidence_score": 0.91
    }
  ],
  "total": 5,
  "page": 1,
  "limit": 10,
  "total_pages": 1
}
```

**Status Codes:**
- 200 OK: Policies retrieved successfully
- 401 Unauthorized: Not authenticated

#### GET /policies/{policy_id}

Get detailed information about a specific policy.

**Response:**
```json
{
  "id": "policy789",
  "policy_number": "HLT-1234567",
  "document_id": "doc123",
  "policy_type": "health_insurance",
  "insurer": "Niva Bupa",
  "effective_date": "2023-01-01",
  "expiration_date": "2024-01-01",
  "status": "active",
  "premium_amount": 12000,
  "premium_frequency": "annual",
  "next_payment_date": "2024-01-01",
  "insured_parties": [
    {
      "name": "John Doe",
      "relationship": "primary",
      "date_of_birth": "1985-04-12"
    },
    {
      "name": "Jane Doe",
      "relationship": "spouse",
      "date_of_birth": "1987-09-23"
    }
  ],
  "coverage": {
    "individual_sum_insured": 500000,
    "family_sum_insured": 1000000,
    "individual_room_rent": "single room",
    "maternity_coverage": true,
    "pre_existing_coverage": "after 36 months",
    "dental_coverage": false,
    "vision_coverage": false
  },
  "deductibles": {
    "in_network": 5000,
    "out_of_network": 10000
  },
  "exclusions": [
    "Cosmetic surgery",
    "Self-inflicted injuries",
    "Experimental treatments"
  ],
  "waiting_periods": {
    "general": "30 days",
    "specific_ailments": "24 months",
    "pre_existing": "36 months",
    "maternity": "24 months"
  },
  "sections": [
    {
      "title": "Definitions",
      "page_range": [3, 5]
    },
    {
      "title": "Coverage Details",
      "page_range": [6, 12],
      "subsections": [
        {
          "title": "Hospital Benefits",
          "page_range": [7, 8]
        },
        {
          "title": "Prescription Coverage",
          "page_range": [9, 10]
        }
      ]
    }
  ],
  "confidence_score": 0.94,
  "extraction_date": "2023-05-25T14:25:45Z"
}
```

**Status Codes:**
- 200 OK: Policy retrieved successfully
- 401 Unauthorized: Not authenticated
- 403 Forbidden: Policy belongs to another user
- 404 Not Found: Policy not found

#### PUT /policies/{policy_id}

Update policy information (for corrections or additional data).

**Request Body:**
```json
{
  "policy_number": "HLT-1234567-A",
  "effective_date": "2023-01-15",
  "premium_amount": 12500,
  "insured_parties": [
    {
      "name": "John Doe",
      "relationship": "primary",
      "date_of_birth": "1985-04-12"
    },
    {
      "name": "Jane Doe",
      "relationship": "spouse",
      "date_of_birth": "1987-09-23"
    },
    {
      "name": "Jake Doe",
      "relationship": "child",
      "date_of_birth": "2015-03-10"
    }
  ]
}
```

**Response:**
```json
{
  "id": "policy789",
  "policy_number": "HLT-1234567-A",
  "effective_date": "2023-01-15",
  "premium_amount": 12500,
  "insured_parties": [
    {
      "name": "John Doe",
      "relationship": "primary",
      "date_of_birth": "1985-04-12"
    },
    {
      "name": "Jane Doe",
      "relationship": "spouse",
      "date_of_birth": "1987-09-23"
    },
    {
      "name": "Jake Doe",
      "relationship": "child",
      "date_of_birth": "2015-03-10"
    }
  ],
  "updated_at": "2023-05-27T11:30:45Z",
  "updated_fields": ["policy_number", "effective_date", "premium_amount", "insured_parties"]
}
```

**Status Codes:**
- 200 OK: Policy updated successfully
- 400 Bad Request: Invalid update data
- 401 Unauthorized: Not authenticated
- 403 Forbidden: Policy belongs to another user
- 404 Not Found: Policy not found

#### GET /policies/{policy_id}/coverage

Get detailed coverage information for a specific policy.

**Response:**
```json
{
  "policy_id": "policy789",
  "policy_number": "HLT-1234567",
  "coverage": {
    "individual_sum_insured": 500000,
    "family_sum_insured": 1000000,
    "individual_room_rent": "single room",
    "room_rent_limit": "1% of sum insured per day",
    "icu_limit": "2% of sum insured per day",
    "pre_hospitalization": "60 days",
    "post_hospitalization": "90 days",
    "day_care_procedures": true,
    "ambulance_cover": 3000,
    "maternity_coverage": true,
    "maternity_waiting_period": "24 months",
    "maternity_limit": 50000,
    "newborn_cover": true,
    "organ_donor_expenses": true,
    "alternative_treatments": false,
    "domiciliary_treatment": true,
    "domiciliary_limit": "10% of sum insured",
    "pre_existing_coverage": "after 36 months",
    "dental_coverage": false,
    "vision_coverage": false,
    "annual_health_checkup": true
  },
  "sub_limits": [
    {
      "procedure": "Cataract Surgery",
      "limit": "20% of sum insured per eye",
      "waiting_period": "24 months"
    },
    {
      "procedure": "Joint Replacement",
      "limit": "50% of sum insured",
      "waiting_period": "36 months"
    }
  ],
  "deductibles": {
    "in_network": 5000,
    "out_of_network": 10000
  },
  "copay": {
    "percentage": 10,
    "applicable_to": ["out_of_network", "certain_procedures"],
    "maximum": 50000
  },
  "add_ons": [
    {
      "name": "Critical Illness Cover",
      "sum_insured": 250000,
      "premium": 2000
    },
    {
      "name": "Personal Accident Cover",
      "sum_insured": 500000,
      "premium": 1500
    }
  ],
  "network_hospitals": {
    "total_count": 5000,
    "major_cities": ["Mumbai", "Delhi", "Bangalore", "Chennai"],
    "directory_link": "https://storage.example.com/networks/niva_bupa_network.pdf"
  }
}
```

**Status Codes:**
- 200 OK: Coverage details retrieved successfully
- 401 Unauthorized: Not authenticated
- 403 Forbidden: Policy belongs to another user
- 404 Not Found: Policy not found

#### GET /policies/compare

Compare multiple policies side by side.

**Query Parameters:**
- `policy_ids`: Comma-separated list of policy IDs to compare

**Response:**
```json
{
  "policies": [
    {
      "id": "policy789",
      "policy_number": "HLT-1234567",
      "policy_type": "health_insurance",
      "insurer": "Niva Bupa",
      "plan_name": "Health Companion"
    },
    {
      "id": "policy791",
      "policy_number": "HLT-9876543",
      "policy_type": "health_insurance",
      "insurer": "HDFC ERGO",
      "plan_name": "My Health Suraksha"
    }
  ],
  "comparison": {
    "basic_details": {
      "effective_date": {
        "policy789": "2023-01-01",
        "policy791": "2022-11-15"
      },
      "expiration_date": {
        "policy789": "2024-01-01",
        "policy791": "2023-11-15"
      },
      "premium_amount": {
        "policy789": 12000,
        "policy791": 10500
      },
      "premium_frequency": {
        "policy789": "annual",
        "policy791": "annual"
      }
    },
    "coverage": {
      "individual_sum_insured": {
        "policy789": 500000,
        "policy791": 400000
      },
      "family_sum_insured": {
        "policy789": 1000000,
        "policy791": 800000
      },
      "room_rent_limit": {
        "policy789": "1% of sum insured per day",
        "policy791": "2% of sum insured per day"
      },
      "pre_hospitalization": {
        "policy789": "60 days",
        "policy791": "30 days"
      },
      "post_hospitalization": {
        "policy789": "90 days",
        "policy791": "60 days"
      },
      "maternity_coverage": {
        "policy789": true,
        "policy791": false
      }
    },
    "waiting_periods": {
      "general": {
        "policy789": "30 days",
        "policy791": "30 days"
      },
      "pre_existing": {
        "policy789": "36 months",
        "policy791": "48 months"
      },
      "specific_ailments": {
        "policy789": "24 months",
        "policy791": "24 months"
      }
    },
    "exclusions": {
      "common": [
        "Cosmetic surgery",
        "Self-inflicted injuries",
        "Experimental treatments"
      ],
      "policy789_only": [
        "Adventure sports injuries"
      ],
      "policy791_only": [
        "Dental treatments",
        "Obesity treatments"
      ]
    },
    "unique_features": {
      "policy789": [
        "Annual health checkup",
        "Maternity coverage",
        "Organ donor expenses"
      ],
      "policy791": [
        "Daily hospital cash",
        "Convalescence benefit"
      ]
    }
  },
  "summary": {
    "coverage_comparison": "Policy HLT-1234567 offers higher sum insured amounts and better maternity benefits, while policy HLT-9876543 has a lower premium.",
    "waiting_period_comparison": "Policy HLT-1234567 has a shorter waiting period for pre-existing conditions (36 months vs 48 months).",
    "key_differences": [
      "Maternity coverage is only available in HLT-1234567",
      "HLT-9876543 has additional exclusions for dental and obesity treatments",
      "HLT-1234567 offers better post-hospitalization coverage (90 days vs 60 days)"
    ]
  }
}
```

**Status Codes:**
- 200 OK: Comparison retrieved successfully
- 400 Bad Request: Invalid policy IDs or too many policies
- 401 Unauthorized: Not authenticated
- 403 Forbidden: One or more policies belong to another user
- 404 Not Found: One or more policies not found

### Question Answering

#### POST /qa/question

Ask a question about insurance policies.

**Request Body:**
```json
{
  "question": "What is my deductible for out-of-network services?",
  "policy_ids": ["policy789", "policy791"],
  "conversation_id": "conv123"
}
```

**Response:**
```json
{
  "question_id": "q456",
  "conversation_id": "conv123",
  "answer": "Your deductible for out-of-network services is ₹10,000 according to your Niva Bupa health insurance policy (HLT-1234567).",
  "confidence_score": 0.92,
  "sources": [
    {
      "policy_id": "policy789",
      "policy_number": "HLT-1234567",
      "document_id": "doc123",
      "section": "Deductibles and Copays",
      "page_range": [15, 15],
      "text": "Out-of-network services are subject to a deductible of ₹10,000 per policy year."
    }
  ],
  "processing_time": 1.45
}
```

**Status Codes:**
- 200 OK: Question answered successfully
- 400 Bad Request: Invalid question format
- 401 Unauthorized: Not authenticated
- 404 Not Found: Policy or conversation not found

#### GET /qa/conversations

List all conversations for the current user.

**Query Parameters:**
- `page` (optional): Page number for pagination
- `limit` (optional): Number of results per page

**Response:**
```json
{
  "conversations": [
    {
      "id": "conv123",
      "title": "Deductible questions",
      "created_at": "2023-05-28T10:15:30Z",
      "updated_at": "2023-05-28T10:20:45Z",
      "message_count": 4,
      "policies": [
        {
          "id": "policy789",
          "policy_number": "HLT-1234567",
          "insurer": "Niva Bupa"
        }
      ],
      "last_message": {
        "content": "Your deductible for out-of-network services is ₹10,000 according to your Niva Bupa health insurance policy (HLT-1234567).",
        "role": "assistant",
        "created_at": "2023-05-28T10:20:45Z"
      }
    },
    {
      "id": "conv124",
      "title": "Coverage questions",
      "created_at": "2023-05-27T14:30:15Z",
      "updated_at": "2023-05-27T14:35:22Z",
      "message_count": 2,
      "policies": [
        {
          "id": "policy791",
          "policy_number": "HLT-9876543",
          "insurer": "HDFC ERGO"
        }
      ],
      "last_message": {
        "content": "Yes, your policy covers hospitalization for COVID-19 treatment after the initial waiting period of 30 days.",
        "role": "assistant",
        "created_at": "2023-05-27T14:35:22Z"
      }
    }
  ],
  "total": 5,
  "page": 1,
  "limit": 10,
  "total_pages": 1
}
```

**Status Codes:**
- 200 OK: Conversations retrieved successfully
- 401 Unauthorized: Not authenticated

#### GET /qa/conversations/{conversation_id}

Get a specific conversation with all messages.

**Response:**
```json
{
  "id": "conv123",
  "title": "Deductible questions",
  "created_at": "2023-05-28T10:15:30Z",
  "updated_at": "2023-05-28T10:20:45Z",
  "policies": [
    {
      "id": "policy789",
      "policy_number": "HLT-1234567",
      "insurer": "Niva Bupa"
    }
  ],
  "messages": [
    {
      "id": "msg1",
      "conversation_id": "conv123",
      "content": "What is my deductible?",
      "role": "user",
      "created_at": "2023-05-28T10:15:30Z"
    },
    {
      "id": "msg2",
      "conversation_id": "conv123",
      "content": "Your policy has different deductibles depending on whether you use in-network or out-of-network services. For in-network services, your deductible is ₹5,000. For out-of-network services, please specify if you'd like that information.",
      "role": "assistant",
      "created_at": "2023-05-28T10:15:45Z",
      "sources": [
        {
          "policy_id": "policy789",
          "section": "Deductibles and Copays",
          "page_range": [15, 15]
        }
      ],
      "confidence_score": 0.95
    },
    {
      "id": "msg3",
      "conversation_id": "conv123",
      "content": "What about out-of-network services?",
      "role": "user",
      "created_at": "2023-05-28T10:20:30Z"
    },
    {
      "id": "msg4",
      "conversation_id": "conv123",
      "content": "Your deductible for out-of-network services is ₹10,000 according to your Niva Bupa health insurance policy (HLT-1234567).",
      "role": "assistant",
      "created_at": "2023-05-28T10:20:45Z",
      "sources": [
        {
          "policy_id": "policy789",
          "section": "Deductibles and Copays",
          "page_range": [15, 15]
        }
      ],
      "confidence_score": 0.92
    }
  ]
}
```

**Status Codes:**
- 200 OK: Conversation retrieved successfully
- 401 Unauthorized: Not authenticated
- 403 Forbidden: Conversation belongs to another user
- 404 Not Found: Conversation not found

#### POST /qa/conversations/{conversation_id}/messages

Add a new message to an existing conversation.

**Request Body:**
```json
{
  "content": "Is there a maximum out-of-pocket limit?",
  "role": "user"
}
```

**Response:**
```json
{
  "message": {
    "id": "msg5",
    "conversation_id": "conv123",
    "content": "Is there a maximum out-of-pocket limit?",
    "role": "user",
    "created_at": "2023-05-28T10:25:15Z"
  },
  "answer": {
    "id": "msg6",
    "conversation_id": "conv123",
    "content": "Yes, your Niva Bupa policy (HLT-1234567) has an annual out-of-pocket maximum of ₹50,000 for in-network services and ₹100,000 for out-of-network services. Once you reach these limits, the policy covers 100% of eligible expenses for the remainder of the policy year.",
    "role": "assistant",
    "created_at": "2023-05-28T10:25:20Z",
    "sources": [
      {
        "policy_id": "policy789",
        "section": "Out-of-Pocket Maximum",
        "page_range": [16, 16]
      }
    ],
    "confidence_score": 0.94
  }
}
```

**Status Codes:**
- 200 OK: Message added successfully
- 400 Bad Request: Invalid message format
- 401 Unauthorized: Not authenticated
- 403 Forbidden: Conversation belongs to another user
- 404 Not Found: Conversation not found

### Notifications

#### GET /notifications

Get notifications for the current user.

**Query Parameters:**
- `page` (optional): Page number for pagination
- `limit` (optional): Number of results per page
- `read` (optional): Filter by read status (`true`, `false`)
- `type` (optional): Filter by notification type

**Response:**
```json
{
  "notifications": [
    {
      "id": "notif123",
      "user_id": "user123",
      "type": "policy_expiration",
      "title": "Policy expiring soon",
      "content": "Your Niva Bupa health insurance policy (HLT-1234567) expires in 30 days.",
      "created_at": "2023-05-28T08:00:00Z",
      "read": false,
      "read_at": null,
      "metadata": {
        "policy_id": "policy789",
        "policy_number": "HLT-1234567",
        "expiration_date": "2024-01-01"
      },
      "actions": [
        {
          "type": "view_policy",
          "label": "View Policy",
          "url": "/policies/policy789"
        },
        {
          "type": "renew_policy",
          "label": "Renew Policy",
          "url": "/policies/policy789/renew"
        }
      ]
    },
    {
      "id": "notif124",
      "user_id": "user123",
      "type": "document_processed",
      "title": "Document processed successfully",
      "content": "Your document 'auto_insurance.pdf' has been processed successfully.",
      "created_at": "2023-05-26T09:15:30Z",
      "read": true,
      "read_at": "2023-05-26T09:20:15Z",
      "metadata": {
        "document_id": "doc124",
        "filename": "auto_insurance.pdf",
        "policy_id": "policy790"
      },
      "actions": [
        {
          "type": "view_document",
          "label": "View Document",
          "url": "/documents/doc124"
        },
        {
          "type": "view_policy",
          "label": "View Policy",
          "url": "/policies/policy790"
        }
      ]
    }
  ],
  "total": 15,
  "unread_count": 5,
  "page": 1,
  "limit": 10,
  "total_pages": 2
}
```

**Status Codes:**
- 200 OK: Notifications retrieved successfully
- 401 Unauthorized: Not authenticated

#### PATCH /notifications/{notification_id}

Update a notification (mark as read/unread).

**Request Body:**
```json
{
  "read": true
}
```

**Response:**
```json
{
  "id": "notif123",
  "read": true,
  "read_at": "2023-05-28T15:30:45Z"
}
```

**Status Codes:**
- 200 OK: Notification updated successfully
- 401 Unauthorized: Not authenticated
- 403 Forbidden: Notification belongs to another user
- 404 Not Found: Notification not found

#### PATCH /notifications

Update multiple notifications (bulk update).

**Request Body:**
```json
{
  "notification_ids": ["notif123", "notif125", "notif126"],
  "read": true
}
```

**Response:**
```json
{
  "updated_count": 3,
  "updated_ids": ["notif123", "notif125", "notif126"]
}
```

**Status Codes:**
- 200 OK: Notifications updated successfully
- 400 Bad Request: Invalid request format
- 401 Unauthorized: Not authenticated

## Error Handling

### Error Response Format

All API errors follow a consistent format:

```json
{
  "error": {
    "code": "error_code",
    "message": "A human-readable error message",
    "details": {
      "field": "additional error context"
    }
  }
}
```

### Common Error Codes

| Error Code | Description |
|------------|-------------|
| `invalid_request` | The request body or parameters are invalid |
| `authentication_required` | Authentication is required for this endpoint |
| `invalid_credentials` | The provided credentials are invalid |
| `token_expired` | The authentication token has expired |
| `insufficient_permissions` | The user does not have permission for this action |
| `resource_not_found` | The requested resource was not found |
| `resource_conflict` | The resource already exists or conflicts with another |
| `rate_limit_exceeded` | API rate limit exceeded |
| `internal_error` | An internal server error occurred |

### Validation Errors

For validation errors, the API returns a 400 status code with detailed field errors:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Validation failed",
    "details": {
      "email": "Email is invalid",
      "password": "Password must be at least 8 characters long"
    }
  }
}
```

## Rate Limiting

The API implements rate limiting to protect against abuse:

- Standard users: 100 requests per minute
- Premium users: 300 requests per minute

Rate limit information is included in the response headers:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1622148120
```

When a rate limit is exceeded, the API returns a 429 (Too Many Requests) status code:

```json
{
  "error": {
    "code": "rate_limit_exceeded",
    "message": "Rate limit exceeded",
    "details": {
      "limit": 100,
      "reset_at": "2023-05-28T10:30:00Z"
    }
  }
}
```

## API Versioning

The API uses URL versioning to maintain backward compatibility:

- Current version: `/v1`
- Future versions will be `/v2`, `/v3`, etc.

API versions are maintained for at least 12 months after a new version is released.

## CORS Policy

The API supports Cross-Origin Resource Sharing (CORS) with the following policies:

- Allowed origins: `https://app.example.com`, `https://admin.example.com`
- Allowed methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`
- Allowed headers: `Content-Type`, `Authorization`
- Exposed headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- Credentials: Allowed
- Max age: 86400 seconds (24 hours)

## Webhooks

The API supports webhooks for real-time event notifications.

### Registering a Webhook

```
POST /webhooks
```

**Request Body:**
```json
{
  "url": "https://your-domain.com/webhook-endpoint",
  "events": ["document.processed", "policy.expiring", "question.answered"],
  "secret": "your_webhook_secret"
}
```

**Response:**
```json
{
  "id": "webhook123",
  "url": "https://your-domain.com/webhook-endpoint",
  "events": ["document.processed", "policy.expiring", "question.answered"],
  "created_at": "2023-05-28T12:00:00Z",
  "status": "active"
}
```

### Webhook Event Format

```json
{
  "event": "document.processed",
  "created_at": "2023-05-28T12:05:30Z",
  "data": {
    "document_id": "doc123",
    "user_id": "user123",
    "status": "completed",
    "processing_time": 180
  },
  "signature": "sha256_hmac_signature"
}
```

### Webhook Signature Verification

Webhook requests include a signature in the `X-Webhook-Signature` header. Verify this signature to ensure the request came from our service:

```python
import hmac
import hashlib

def verify_webhook_signature(payload, signature, secret):
    computed_signature = hmac.new(
        secret.encode("utf-8"),
        payload.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(computed_signature, signature)
```

## API Changelog

### v1.0.0 (2023-05-01)

- Initial release with core functionality:
  - Authentication
  - Document upload and processing
  - Policy information
  - Basic question answering

### v1.1.0 (2023-06-15)

- Added policy comparison endpoint
- Enhanced question answering with conversation history
- Added notifications endpoint
- Improved document processing status reporting

### v1.2.0 (2023-08-01)

- Added webhook support
- Enhanced policy coverage details
- Added bulk operations for documents
- Improved error handling and validation
