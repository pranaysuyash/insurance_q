# Anti-Abuse System Documentation

## Overview

This document outlines a comprehensive multi-layered anti-abuse system for the Insurance RAG application that prevents misuse while maintaining a low-friction user experience for lead generation.

## Problem Statement

Traditional email-based rate limiting can be easily bypassed using:
- Disposable email generators (10minutemail, tempmail, etc.)
- Multiple email accounts
- Fake email addresses

Our solution leverages extracted insurance document data for more robust validation.

## Multi-Layer Defense Strategy

### Layer 1: Document-Based Validation (Primary)
**Concept**: Use actual insurance policy data for tracking instead of user-provided emails.

**Implementation**:
- Extract key identifiers: policy number, policyholder name, insurance company
- Create composite fingerprint from normalized data
- Track usage per unique policy/person combination
- Allow 3-5 analyses per policy holder per month (regardless of email used)

**Advantages**:
- Cannot be bypassed with fake emails
- Uses actual business data for validation
- Allows legitimate family members to use different emails for same policy
- Much harder to game the system

### Layer 2: Email Validation (Secondary)
**Implementation**:
- Block known disposable email domains
- Cross-reference email names with extracted policyholder names
- Maintain email-based limits as backup validation
- Optional email verification for higher usage tiers

### Layer 3: Behavioral Analysis (Tertiary)
**Implementation**:
- Rate limit per IP address (e.g., 10 uploads per day)
- Track session behavior patterns
- Implement progressive delays for rapid requests
- Monitor time between uploads

### Layer 4: Document Content Validation
**Implementation**:
- Hash document content to prevent reprocessing same document
- Validate document structure and format
- Verify insurance company names against known providers
- Detect obviously fake or template documents

## Implementation Phases

### Phase 1: Quick Wins (Immediate Implementation)
**Priority**: High
**Effort**: Low
**Impact**: Medium

1. **Document Content Hashing**
   - Prevent reprocessing identical documents
   - Store SHA-256 hash of document content
   - Return cached results for duplicate documents

2. **IP-Based Rate Limiting**
   - Limit to 10 uploads per day per IP address
   - Use Redis for fast lookup and expiration
   - Implement sliding window rate limiting

3. **Session-Based Limits**
   - Limit to 5 uploads per session
   - Track session UUID for anonymous users
   - Reset limits on new session

4. **Basic Disposable Email Blocking**
   - Maintain list of known disposable email domains
   - Block or flag suspicious email patterns
   - Allow override for legitimate business use

### Phase 2: Smart Validation (Medium Term)
**Priority**: High
**Effort**: Medium
**Impact**: High

1. **Enhanced OCR Extraction**
   - Extract policy numbers, names, addresses
   - Normalize and standardize extracted data
   - Handle various document formats and layouts

2. **Policy-Based Fingerprinting**
   - Create composite hash from policy identifiers
   - Track usage per policy fingerprint
   - Cross-reference multiple submissions

3. **Name/Email Cross-Validation**
   - Compare extracted names with email addresses
   - Flag mismatches for manual review
   - Allow family member variations

4. **Behavioral Pattern Detection**
   - Analyze upload timing patterns
   - Detect automated behavior
   - Flag suspicious activity for review

### Phase 3: Business Model Integration (Long Term)
**Priority**: Medium
**Effort**: High
**Impact**: High

1. **Tiered Usage Limits**
   - Free tier: 3 analyses per policy per month
   - Verified tier: 10 analyses (email verification required)
   - Business tier: Unlimited (payment required)
   - Enterprise tier: API access with authentication

2. **Advanced Fraud Detection**
   - Machine learning for pattern recognition
   - Anomaly detection algorithms
   - Real-time risk scoring

3. **Premium Features**
   - Priority processing for paid users
   - Advanced analytics and reporting
   - Bulk document processing

## Technical Implementation

### Database Schema

```sql
-- Usage tracking table
CREATE TABLE usage_tracking (
    id SERIAL PRIMARY KEY,
    policy_fingerprint VARCHAR(64),
    document_hash VARCHAR(64) NOT NULL,
    user_email VARCHAR(255),
    ip_address INET,
    session_id VARCHAR(255),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    extracted_metadata JSONB,
    usage_tier VARCHAR(20) DEFAULT 'free'
);

-- Indexes for performance
CREATE INDEX idx_policy_fingerprint_month ON usage_tracking 
(policy_fingerprint, DATE_TRUNC('month', created_at));

CREATE INDEX idx_document_hash ON usage_tracking (document_hash);
CREATE INDEX idx_ip_date ON usage_tracking (ip_address, DATE(created_at));
CREATE INDEX idx_session_date ON usage_tracking (session_id, DATE(created_at));

-- Blocked domains table
CREATE TABLE blocked_domains (
    id SERIAL PRIMARY KEY,
    domain VARCHAR(255) UNIQUE NOT NULL,
    reason VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Known insurance companies
CREATE TABLE insurance_companies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    aliases TEXT[], -- Array of alternative names
    verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### Core Functions

```python
import hashlib
import re
from typing import Dict, Optional, Tuple

def create_policy_fingerprint(extracted_data: Dict) -> str:
    """Create a unique fingerprint from policy data."""
    policy_num = normalize_policy_number(extracted_data.get('policy_number', ''))
    name = normalize_name(extracted_data.get('policyholder_name', ''))
    company = normalize_company(extracted_data.get('insurance_company', ''))
    
    # Create composite hash
    composite = f"{policy_num}:{name}:{company}"
    fingerprint = hashlib.sha256(composite.encode()).hexdigest()
    return fingerprint

def normalize_policy_number(policy_num: str) -> str:
    """Normalize policy number for consistent matching."""
    if not policy_num:
        return ""
    # Remove spaces, hyphens, and convert to uppercase
    return re.sub(r'[\s\-]', '', policy_num.upper())

def normalize_name(name: str) -> str:
    """Normalize person name for consistent matching."""
    if not name:
        return ""
    # Convert to lowercase, remove extra spaces
    return ' '.join(name.lower().split())

def normalize_company(company: str) -> str:
    """Normalize insurance company name."""
    if not company:
        return ""
    # Remove common suffixes and normalize
    company = company.lower()
    suffixes = ['inc', 'ltd', 'llc', 'corp', 'corporation', 'limited']
    for suffix in suffixes:
        company = re.sub(rf'\b{suffix}\b\.?', '', company)
    return ' '.join(company.split())

def check_usage_limits(
    policy_fingerprint: str,
    ip_address: str,
    session_id: str,
    document_hash: str
) -> Tuple[bool, str]:
    """Check all usage limits and return (allowed, reason)."""
    
    # Check document hash (prevent reprocessing)
    if document_already_processed(document_hash):
        return False, "Document already processed"
    
    # Check IP rate limits
    if get_ip_uploads_today(ip_address) >= 10:
        return False, "Daily IP limit exceeded"
    
    # Check session limits
    if get_session_uploads_today(session_id) >= 5:
        return False, "Session limit exceeded"
    
    # Check policy-based limits (if fingerprint available)
    if policy_fingerprint:
        monthly_usage = get_policy_usage_this_month(policy_fingerprint)
        if monthly_usage >= 5:  # Free tier limit
            return False, "Monthly policy limit exceeded"
    
    return True, "OK"

def validate_email_against_extracted_data(
    email: str,
    extracted_name: str
) -> Tuple[bool, str]:
    """Validate email against extracted policyholder name."""
    if not email or not extracted_name:
        return True, "Insufficient data for validation"
    
    # Extract name from email
    email_name = email.split('@')[0].lower()
    extracted_name_parts = extracted_name.lower().split()
    
    # Check if any part of extracted name appears in email
    for name_part in extracted_name_parts:
        if len(name_part) > 2 and name_part in email_name:
            return True, "Name match found"
    
    # Allow some flexibility for family members, nicknames, etc.
    return True, "Name validation skipped (family member allowance)"
```

### Rate Limiting Implementation

```python
import redis
from datetime import datetime, timedelta

redis_client = redis.Redis(host='localhost', port=6379, db=0)

def check_ip_rate_limit(ip_address: str, limit: int = 10) -> bool:
    """Check IP-based rate limiting using sliding window."""
    key = f"ip_limit:{ip_address}"
    current_time = datetime.now()
    
    # Remove old entries (older than 24 hours)
    redis_client.zremrangebyscore(
        key, 
        0, 
        (current_time - timedelta(days=1)).timestamp()
    )
    
    # Count current entries
    current_count = redis_client.zcard(key)
    
    if current_count >= limit:
        return False
    
    # Add current request
    redis_client.zadd(key, {str(current_time.timestamp()): current_time.timestamp()})
    redis_client.expire(key, 86400)  # 24 hours
    
    return True

def check_session_rate_limit(session_id: str, limit: int = 5) -> bool:
    """Check session-based rate limiting."""
    key = f"session_limit:{session_id}"
    current_time = datetime.now()
    
    # Remove old entries (older than 24 hours)
    redis_client.zremrangebyscore(
        key,
        0,
        (current_time - timedelta(days=1)).timestamp()
    )
    
    current_count = redis_client.zcard(key)
    
    if current_count >= limit:
        return False
    
    redis_client.zadd(key, {str(current_time.timestamp()): current_time.timestamp()})
    redis_client.expire(key, 86400)
    
    return True
```

## Monitoring and Analytics

### Key Metrics to Track

1. **Usage Patterns**
   - Uploads per day/hour
   - Peak usage times
   - Geographic distribution

2. **Abuse Detection**
   - Blocked requests by reason
   - Suspicious activity patterns
   - False positive rates

3. **Business Metrics**
   - Conversion rates (upload to lead)
   - User retention
   - Premium tier adoption

### Alerting

- High volume of blocked requests
- Unusual traffic patterns
- System performance degradation
- New disposable email domains detected

## Privacy and Compliance

### Data Handling
- Hash sensitive personal information
- Implement data retention policies
- Provide user data deletion options
- Comply with GDPR/CCPA requirements

### Transparency
- Clear privacy policy about usage tracking
- Explain rate limiting to users
- Provide appeals process for false positives
- Option to upgrade for higher limits

## Future Enhancements

1. **Machine Learning Integration**
   - Anomaly detection for unusual patterns
   - Predictive modeling for abuse prevention
   - Automated threshold adjustment

2. **Advanced Fingerprinting**
   - Document layout analysis
   - Metadata extraction and validation
   - Cross-document relationship detection

3. **Real-time Risk Scoring**
   - Dynamic limit adjustment based on risk
   - Behavioral analysis integration
   - Reputation-based scoring

## Testing Strategy

### Unit Tests
- Individual function validation
- Edge case handling
- Performance benchmarks

### Integration Tests
- End-to-end workflow testing
- Database interaction validation
- Redis integration testing

### Load Testing
- High-volume request simulation
- Rate limiting effectiveness
- System performance under stress

## Deployment Considerations

### Environment Variables
```bash
# Rate limiting configuration
RATE_LIMIT_IP_DAILY=10
RATE_LIMIT_SESSION_DAILY=5
RATE_LIMIT_POLICY_MONTHLY=5

# Redis configuration
REDIS_URL=redis://localhost:6379/0

# Feature flags
ENABLE_POLICY_FINGERPRINTING=true
ENABLE_EMAIL_VALIDATION=true
ENABLE_BEHAVIORAL_ANALYSIS=false
```

### Monitoring Setup
- Application performance monitoring
- Rate limiting metrics dashboard
- Abuse detection alerts
- User experience impact tracking

This comprehensive approach provides robust protection against abuse while maintaining the low-friction user experience essential for lead generation. 