# Data Storage and Management

This document outlines the data storage architecture and management strategies for the Insurance Policy Parser & QA App.

## Overview

The data storage architecture is designed to efficiently handle various types of data including user information, document storage, structured policy metadata, and vector embeddings for semantic search. The system uses a multi-database approach to optimize for different access patterns and data types.

## Data Categories

The application manages the following categories of data:

1. **User Data**: Authentication details, profiles, preferences
2. **Document Data**: Original policy documents, processed versions
3. **Structured Metadata**: Extracted policy information in structured format
4. **Vector Data**: Embeddings for text chunks to enable semantic search
5. **Conversation Data**: User questions and system responses
6. **Application Data**: System settings, logs, usage statistics

## Storage Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      APPLICATION SERVICES                        │
└───────────┬─────────────┬────────────┬────────────┬─────────────┘
            │             │            │            │
            ▼             ▼            ▼            ▼
┌───────────────┐ ┌─────────────┐ ┌──────────┐ ┌──────────────┐
│ RELATIONAL DB │ │ DOCUMENT    │ │ VECTOR   │ │ OBJECT       │
│ (PostgreSQL)  │ │ STORE       │ │ DATABASE │ │ STORAGE      │
│               │ │ (MongoDB)   │ │ (FAISS/  │ │ (S3/GCS)     │
│ - User data   │ │             │ │ Pinecone)│ │              │
│ - Auth info   │ │ - Policy    │ │          │ │ - PDF docs   │
│ - Preferences │ │   metadata  │ │ - Text   │ │ - Processed  │
│ - Billing     │ │ - Extracted │ │   embeddi│ │   versions   │
│ - App config  │ │   data      │ │   ngs    │ │ - Exported   │
│               │ │ - Structure │ │ - Semanti│ │   reports    │
│               │ │   info      │ │   c index│ │              │
└───────┬───────┘ └─────┬───────┘ └────┬─────┘ └──────┬───────┘
        │               │              │              │
        └───────────────┴──────────────┴──────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CACHING LAYER (Redis)                       │
│                                                                  │
│ - Frequently accessed policy data                                │
│ - User session information                                       │
│ - Common query results                                           │
│ - Authentication tokens                                          │
└─────────────────────────────────────────────────────────────────┘
```

## Database Components

### 1. Relational Database (PostgreSQL)

PostgreSQL serves as the primary transactional database for structured data with complex relationships.

**Stored Data:**
- User accounts and profiles
- Authentication and authorization information
- Subscription and billing details
- Relationship mapping between users and policies
- Configuration settings
- Audit logs

**Key Characteristics:**
- ACID compliance
- Strong consistency
- Complex query capabilities
- Transaction support
- Robust security model

**Schema Highlights:**
```sql
-- User Management
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE,
    account_status VARCHAR(50) NOT NULL,
    subscription_tier VARCHAR(50) DEFAULT 'free'
);

-- User Preferences
CREATE TABLE user_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    notification_email BOOLEAN DEFAULT TRUE,
    notification_web BOOLEAN DEFAULT TRUE,
    theme VARCHAR(50) DEFAULT 'light',
    language VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(50) DEFAULT 'UTC'
);

-- Document Management
CREATE TABLE documents (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    filename VARCHAR(255) NOT NULL,
    original_path VARCHAR(512) NOT NULL,
    processed_path VARCHAR(512),
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    processing_completed_at TIMESTAMP WITH TIME ZONE,
    version INT DEFAULT 1,
    previous_version_id UUID REFERENCES documents(id)
);

-- Policies (Metadata)
CREATE TABLE policies (
    id UUID PRIMARY KEY,
    document_id UUID REFERENCES documents(id),
    policy_number VARCHAR(100),
    policy_type VARCHAR(50),
    insurer VARCHAR(255),
    effective_date DATE,
    expiration_date DATE,
    premium_amount NUMERIC(10,2),
    premium_frequency VARCHAR(50),
    metadata_json JSONB,
    confidence_score NUMERIC(5,2)
);
```

### 2. Document Store (MongoDB)

MongoDB serves as a flexible document store for semi-structured policy data and extracted information.

**Stored Data:**
- Extracted policy metadata
- Document structure information
- Section and content organization
- Table data from policies
- Key-value pairs extracted from policies
- Semantic chunking metadata

**Key Characteristics:**
- Schema flexibility
- Document-oriented storage
- Good query performance for document retrieval
- Native JSON support
- Horizontal scaling options

**Collection Examples:**
```javascript
// Policy Metadata Collection
{
  "_id": "policy_uuid",
  "document_id": "document_uuid",
  "policy_number": "POL-1234567",
  "insurer": "Example Insurance Co",
  "policy_type": "health",
  "effective_date": ISODate("2023-01-01"),
  "expiration_date": ISODate("2024-01-01"),
  "premium": {
    "amount": 350.00,
    "frequency": "monthly",
    "next_due_date": ISODate("2023-05-01")
  },
  "coverage": {
    "type": "family",
    "members": ["Primary", "Spouse", "Dependent1"],
    "limits": {
      "individual_deductible": 1000.00,
      "family_deductible": 2000.00,
      "out_of_pocket_max": 5000.00
    }
  },
  "exclusions": [
    "Pre-existing conditions for first 6 months",
    "Elective cosmetic procedures",
    "Experimental treatments"
  ],
  "extracted_at": ISODate("2023-04-15T14:30:00Z"),
  "confidence_score": 0.92
}

// Document Structure Collection
{
  "_id": "structure_uuid",
  "document_id": "document_uuid",
  "total_pages": 24,
  "sections": [
    {
      "title": "Definitions",
      "start_page": 3,
      "end_page": 5,
      "level": 1
    },
    {
      "title": "Coverage Details",
      "start_page": 6,
      "end_page": 12,
      "level": 1,
      "subsections": [
        {
          "title": "Hospital Benefits",
          "start_page": 7,
          "end_page": 8,
          "level": 2
        },
        {
          "title": "Prescription Coverage",
          "start_page": 9,
          "end_page": 10,
          "level": 2
        }
      ]
    }
  ],
  "tables": [
    {
      "title": "Benefit Schedule",
      "page": 8,
      "rows": 15,
      "columns": 3,
      "data_id": "table_data_uuid"
    }
  ]
}
```

### 3. Vector Database (FAISS/Pinecone)

The vector database stores text embeddings for semantic search and retrieval.

**Stored Data:**
- Document chunk embeddings
- Metadata for chunk retrieval
- Vector indices for similarity search
- Query embedding cache

**Key Characteristics:**
- Optimized for similarity search
- Low-latency vector operations
- Scalable to millions of vectors
- Support for metadata filtering
- Advanced ranking capabilities

**Implementation:**
```python
# Example structure for vector storage
class TextChunk:
    id: str  # UUID
    document_id: str  # Reference to source document
    policy_id: str  # Reference to policy
    text: str  # The actual text content
    embedding: List[float]  # Vector representation (typically 768-1536 dimensions)
    metadata: Dict[str, Any]  # Additional metadata for filtering
    start_page: int  # Page where chunk starts
    end_page: int  # Page where chunk ends
    section_path: str  # Hierarchical section path
    chunk_type: str  # Type of content (regular text, table, definition, etc.)
    
# Vector storage schema (conceptual)
vector_store = {
    "namespace": "insurance_policies",
    "dimensions": 1536,  # Using OpenAI's embedding dimension as example
    "metric": "cosine",  # Similarity metric
    "vectors": [
        {
            "id": "chunk_uuid",
            "values": [0.1, 0.2, ...],  # The actual vector
            "metadata": {
                "policy_id": "policy_uuid",
                "document_id": "document_uuid",
                "policy_type": "health",
                "insurer": "Example Insurance Co",
                "section": "Coverage Details",
                "page_numbers": [7, 8],
                "chunk_type": "text"
            }
        },
        # ... more vectors
    ]
}
```

### 4. Object Storage (S3/GCS)

Object storage is used for large binary objects such as original documents and processed versions.

**Stored Data:**
- Original PDF documents
- Processed document versions
- OCR results
- Generated reports
- Exported data

**Key Characteristics:**
- Highly scalable
- Cost-effective for large files
- Versioning capabilities
- Access control at object level
- Durability and redundancy

**Storage Organization:**
```
bucket/
├── users/
│   └── {user_id}/
│       ├── documents/
│       │   ├── {document_id}/
│       │   │   ├── original.pdf
│       │   │   ├── processed.pdf
│       │   │   └── ocr/
│       │   │       ├── page_01.txt
│       │   │       ├── page_02.txt
│       │   │       └── ...
│       │   └── ...
│       └── exports/
│           ├── {export_id}.pdf
│           └── ...
└── system/
    └── templates/
        ├── report_template.html
        └── ...
```

### 5. Caching Layer (Redis)

Redis provides caching for frequently accessed data and supports ephemeral data needs.

**Cached Data:**
- Frequently accessed policy information
- Authentication tokens and session data
- Common query results
- Rate limiting counters
- Task queues for document processing

**Key Characteristics:**
- In-memory performance
- Support for complex data structures
- Pub/sub capabilities
- Data expiration policies
- Cluster support for scaling

**Caching Strategies:**
1. **User Session Caching**
   - Cache user session data with appropriate TTL
   - Store authentication tokens and permissions

2. **Policy Data Caching**
   - Cache frequently accessed policy metadata
   - Invalidate on policy updates

3. **Query Result Caching**
   - Cache common question results
   - Implement LRU eviction policy
   - Set appropriate TTL based on data volatility

4. **Processing Job Management**
   - Track document processing status
   - Implement job queues for background tasks

## Data Access Patterns

### User Data Access

User data is primarily accessed through the relational database with Redis caching for active sessions:

1. **Authentication Flow**
   - Query PostgreSQL for user credentials during login
   - Cache authentication tokens in Redis
   - Refresh tokens handled through secure PostgreSQL transactions

2. **Profile Management**
   - Direct CRUD operations against PostgreSQL
   - Cache frequently accessed profile data in Redis
   - Invalidate cache on profile updates

### Document Processing Access

Document processing involves multiple data stores:

1. **Upload Flow**
   - Store original document in Object Storage
   - Create metadata record in PostgreSQL
   - Queue processing job in Redis
   - Update processing status in PostgreSQL as job progresses

2. **Extraction Flow**
   - Read original document from Object Storage
   - Write extracted metadata to MongoDB
   - Store processed document version in Object Storage
   - Update document status in PostgreSQL
   - Generate and store text chunks in MongoDB
   - Create and store embeddings in Vector Database

### Question Answering Access

The QA system uses a complex access pattern across multiple stores:

1. **Question Processing**
   - Generate query embedding
   - Search Vector Database for relevant chunks
   - Retrieve chunk metadata and text from MongoDB
   - Fetch additional context from MongoDB if needed
   - Generate and store the answer in MongoDB
   - Cache frequent questions and answers in Redis

2. **Conversation History**
   - Store conversation history in MongoDB
   - Link conversations to users in PostgreSQL
   - Maintain recent conversation context in Redis

## Data Migration and Evolution

The system implements a structured approach to data schema evolution:

### Schema Evolution

1. **Relational Database**
   - Use migrations with version control
   - Implement backward compatibility layers
   - Use schema evolution strategies (expand/contract pattern)

2. **Document Store**
   - Use schema versioning for documents
   - Implement on-read transformations for older schemas
   - Batch update documents during maintenance windows

### Data Migration

1. **Upgrade Strategies**
   - In-place upgrades for minor changes
   - Blue/green deployment for major schema changes
   - Canary testing for migration validation

2. **Backup and Recovery**
   - Regular automated backups of all data stores
   - Point-in-time recovery capabilities
   - Cross-region replication for disaster recovery

## Data Security

### Encryption

1. **Data at Rest**
   - Encrypted storage for all databases
   - Document encryption in Object Storage
   - Secure key management

2. **Data in Transit**
   - TLS for all network communications
   - API-level encryption for sensitive data
   - Secure VPC connections between services

### Access Control

1. **Authentication**
   - Multi-factor authentication for database access
   - Service account minimization
   - Key rotation policies

2. **Authorization**
   - Role-based access control
   - Principle of least privilege
   - Resource-level permissions

### Compliance Measures

1. **Audit Logging**
   - Comprehensive access logging
   - Change tracking and history
   - Immutable audit trail for sensitive operations

2. **Data Governance**
   - Data classification and handling policies
   - Retention and deletion policies
   - GDPR and CCPA compliance mechanisms

## Performance Optimization

### Indexing Strategy

1. **Relational Database**
   - Strategic indexing based on query patterns
   - Regular index maintenance
   - Partial indexes for large tables

2. **Document Store**
   - Compound indexes for common query patterns
   - Text indexes for content search
   - TTL indexes for time-based expiration

3. **Vector Database**
   - Optimized index structures (HNSW, IVF)
   - Quantization for space efficiency
   - Metadata indexing for filtered searches

### Sharding and Partitioning

1. **Horizontal Sharding**
   - User-based sharding for multi-tenant isolation
   - Date-based partitioning for time-series data
   - Document count limits per shard

2. **Vertical Partitioning**
   - Separate frequently and infrequently accessed data
   - Split large documents into logical components
   - Optimize for query patterns

### Caching Strategy

1. **Multi-Level Caching**
   - Application-level caching
   - Database result caching
   - Object caching
   - Computed value caching

2. **Invalidation Strategies**
   - Time-based expiration
   - Event-based invalidation
   - Version-tagged cache entries

## Monitoring and Maintenance

### Performance Monitoring

1. **Key Metrics**
   - Query performance and execution time
   - Cache hit/miss ratios
   - Storage utilization and growth rates
   - Read/write operation volumes

2. **Alerting**
   - Performance threshold alerts
   - Error rate monitoring
   - Capacity planning alerts
   - Anomaly detection

### Maintenance Procedures

1. **Regular Maintenance**
   - Index optimization
   - Vacuum operations for PostgreSQL
   - Compaction for MongoDB
   - Log rotation and cleanup

2. **Scaling Operations**
   - Automated scaling triggers
   - Manual scaling procedures
   - Capacity planning review process
   - Performance tuning guidelines

## Future Enhancements

### Planned Improvements

1. **Advanced Caching**
   - Predictive caching based on user behavior
   - Machine learning-based cache warming
   - Distributed caching improvements

2. **Enhanced Vector Search**
   - Hybrid search combining vector and keyword approaches
   - Contextual re-ranking
   - Learning-to-rank for result improvement

3. **Data Analytics**
   - Enhanced analytics storage
   - Real-time data processing pipeline
   - Machine learning feature store
   - User behavior analysis
