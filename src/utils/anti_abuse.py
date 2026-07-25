"""
Anti-abuse utilities for the Insurance RAG application.
Implements Phase 1: Quick wins for preventing misuse.
"""

import hashlib
import re
import redis
from datetime import datetime, timedelta, timezone
from typing import Dict, Tuple
import logging
from functools import wraps
import os
from src.utils.runtime_config import supabase_server_key

logger = logging.getLogger(__name__)

# Anti-abuse database path (configurable for tests)
ANTI_ABUSE_DB_PATH = os.getenv('ANTI_ABUSE_DB_PATH', 'insurance_app.db')

# Redis client for rate limiting.
# Build the URL from REDIS_HOST/REDIS_PORT/REDIS_PASSWORD (what the deploy
# scripts set), falling back to REDIS_URL if provided, then localhost.
try:
    redis_host = os.getenv('REDIS_HOST')
    if redis_host:
        redis_port = os.getenv('REDIS_PORT', '6379')
        redis_password = os.getenv('REDIS_PASSWORD', '')
        redis_url = (
            f"redis://:{redis_password}@{redis_host}:{redis_port}/0"
            if redis_password
            else f"redis://{redis_host}:{redis_port}/0"
        )
    else:
        redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
    redis_client = redis.from_url(redis_url)
    # Test connection
    redis_client.ping()
    logger.info("Redis connection established for rate limiting")
except Exception:
    # CSO F5: never log the redis_url (which contains the password) or the
    # exception message (which may include the URL). Use a generic message.
    logger.warning("Redis not available, using in-memory fallback")
    redis_client = None

# In-memory fallback for rate limiting when Redis is not available
_memory_store = {}

# Known disposable email domains (Phase 1 basic list)
DISPOSABLE_EMAIL_DOMAINS = {
    '10minutemail.com', 'tempmail.org', 'guerrillamail.com', 'mailinator.com',
    'throwaway.email', 'temp-mail.org', 'getairmail.com', 'fakemailgenerator.com',
    'yopmail.com', 'maildrop.cc', 'sharklasers.com', 'grr.la', 'guerrillamailblock.com',
    'pokemail.net', 'spam4.me', 'bccto.me', 'chacuo.net', 'dispostable.com',
    'emailondeck.com', 'fakeinbox.com', 'hide.biz.st', 'mytrashmail.com',
    'nobulk.com', 'sogetthis.com', 'spamherelots.com', 'superrito.com',
    'trashmail.net', 'wegwerfmail.de', 'zehnminuten.de'
}

# Rate limiting configuration
RATE_LIMITS = {
    'ip_daily': int(os.getenv('RATE_LIMIT_IP_DAILY', '10')),
    'session_daily': int(os.getenv('RATE_LIMIT_SESSION_DAILY', '5')),
    'policy_monthly': int(os.getenv('RATE_LIMIT_POLICY_MONTHLY', '5'))
}

def create_document_hash(content: bytes) -> str:
    """Create SHA-256 hash of document content for duplicate detection."""
    return hashlib.sha256(content).hexdigest()

def is_disposable_email(email: str) -> bool:
    """Check if email domain is from a known disposable email service."""
    if not email or '@' not in email:
        return False
    
    domain = email.split('@')[1].lower()
    return domain in DISPOSABLE_EMAIL_DOMAINS

def get_client_ip(request) -> str:
    """Extract client IP address from request, handling proxies."""
    # Check for forwarded IP (common in production behind load balancers)
    forwarded_for = request.headers.get('X-Forwarded-For')
    if forwarded_for:
        # Take the first IP in the chain
        return forwarded_for.split(',')[0].strip()
    
    # Check for real IP header
    real_ip = request.headers.get('X-Real-IP')
    if real_ip:
        return real_ip
    
    # Fallback to direct client IP
    return request.client.host

def _get_redis_key(key_type: str, identifier: str) -> str:
    """Generate Redis key for rate limiting."""
    return f"rate_limit:{key_type}:{identifier}"

def _cleanup_old_entries(key: str, window_hours: int = 24):
    """Remove old entries from Redis sorted set."""
    if not redis_client:
        return
    
    cutoff_time = (datetime.now() - timedelta(hours=window_hours)).timestamp()
    redis_client.zremrangebyscore(key, 0, cutoff_time)

def _get_memory_store_key(key_type: str, identifier: str) -> str:
    """Generate memory store key for fallback rate limiting."""
    return f"{key_type}:{identifier}"

def _cleanup_memory_store():
    """Clean up old entries from memory store."""
    current_time = datetime.now()
    keys_to_remove = []
    
    for key, entries in _memory_store.items():
        # Remove entries older than 24 hours
        _memory_store[key] = [
            entry for entry in entries 
            if current_time - entry < timedelta(hours=24)
        ]
        
        # Remove empty keys
        if not _memory_store[key]:
            keys_to_remove.append(key)
    
    for key in keys_to_remove:
        del _memory_store[key]

def check_ip_rate_limit(ip_address: str, limit: int = None) -> Tuple[bool, str]:
    """Check IP-based rate limiting using sliding window."""
    if limit is None:
        limit = RATE_LIMITS['ip_daily']
    
    if redis_client:
        return _check_redis_rate_limit('ip', ip_address, limit, 24)
    else:
        return _check_memory_rate_limit('ip', ip_address, limit, 24)

def check_session_rate_limit(session_id: str, limit: int = None) -> Tuple[bool, str]:
    """Check session-based rate limiting."""
    if limit is None:
        limit = RATE_LIMITS['session_daily']
    
    if redis_client:
        return _check_redis_rate_limit('session', session_id, limit, 24)
    else:
        return _check_memory_rate_limit('session', session_id, limit, 24)

def _check_redis_rate_limit(
    key_type: str, 
    identifier: str, 
    limit: int, 
    window_hours: int
) -> Tuple[bool, str]:
    """Check rate limit using Redis sorted sets."""
    key = _get_redis_key(key_type, identifier)
    current_time = datetime.now()
    
    try:
        # Clean up old entries
        _cleanup_old_entries(key, window_hours)
        
        # Count current entries
        current_count = redis_client.zcard(key)
        
        if current_count >= limit:
            return False, f"{key_type.title()} rate limit exceeded ({current_count}/{limit})"
        
        # Add current request
        timestamp = current_time.timestamp()
        redis_client.zadd(key, {str(timestamp): timestamp})
        redis_client.expire(key, window_hours * 3600)  # Set expiration
        
        return True, f"OK ({current_count + 1}/{limit})"
        
    except Exception:
        # CSO F5: never log Redis error details (may contain password/URL).
        logger.warning("Redis rate limiting unavailable, allowing request")
        return True, "Rate limiting unavailable"

def _check_memory_rate_limit(
    key_type: str, 
    identifier: str, 
    limit: int, 
    window_hours: int
) -> Tuple[bool, str]:
    """Check rate limit using in-memory store (fallback)."""
    key = _get_memory_store_key(key_type, identifier)
    current_time = datetime.now()
    
    # Clean up old entries periodically
    _cleanup_memory_store()
    
    # Get or create entry list
    if key not in _memory_store:
        _memory_store[key] = []
    
    # Remove old entries for this key
    cutoff_time = current_time - timedelta(hours=window_hours)
    _memory_store[key] = [
        entry for entry in _memory_store[key] 
        if entry > cutoff_time
    ]
    
    current_count = len(_memory_store[key])
    
    if current_count >= limit:
        return False, f"{key_type.title()} rate limit exceeded ({current_count}/{limit})"
    
    # Add current request
    _memory_store[key].append(current_time)
    
    return True, f"OK ({current_count + 1}/{limit})"

def check_document_hash_exists(document_hash: str) -> bool:
    """Check if document hash already exists in the system."""
    try:
        from src.utils.database_migration import check_document_hash_exists_db
        return check_document_hash_exists_db(document_hash, ANTI_ABUSE_DB_PATH)
    except ImportError:
        logger.warning("Database migration module not available, skipping hash check")
        return False

def validate_email_format(email: str) -> Tuple[bool, str]:
    """Basic email format validation."""
    if not email:
        return False, "Email is required"
    
    # Basic email regex
    email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    if not re.match(email_pattern, email):
        return False, "Invalid email format"
    
    # Check for disposable email
    if is_disposable_email(email):
        return False, "Disposable email addresses are not allowed"
    
    return True, "Valid email"

def check_all_rate_limits(
    ip_address: str,
    session_id: str,
    document_hash: str,
    email: str = None
) -> Tuple[bool, str]:
    """Check all rate limits and validations."""
    
    # Check document hash (prevent reprocessing)
    if check_document_hash_exists(document_hash):
        return False, "Document has already been processed"
    
    # Check IP rate limits
    ip_allowed, ip_reason = check_ip_rate_limit(ip_address)
    if not ip_allowed:
        return False, ip_reason
    
    # Check session rate limits
    session_allowed, session_reason = check_session_rate_limit(session_id)
    if not session_allowed:
        return False, session_reason
    
    # Validate email if provided
    if email:
        email_valid, email_reason = validate_email_format(email)
        if not email_valid:
            return False, email_reason
    
    return True, "All checks passed"


def check_supabase_rate_limits(
    ip_address: str,
    session_id: str,
) -> Tuple[bool, str]:
    """Consume the canonical Postgres rate-limit windows.

    Production must not fall back to process memory or Redis because Cloud
    Run instances would each see a different counter. Identifiers are hashed
    before they cross the database boundary.
    """
    from src.utils.supabase_client import create_client

    url = os.getenv("SUPABASE_URL", "").strip()
    key = supabase_server_key()
    if not url or not key:
        raise RuntimeError("Supabase rate limiting requires server credentials")
    client = create_client(url, key)
    for scope, identifier, limit in (
        ("ip_daily", ip_address, RATE_LIMITS["ip_daily"]),
        ("session_daily", session_id, RATE_LIMITS["session_daily"]),
    ):
        identifier_hash = hashlib.sha256(identifier.encode("utf-8")).hexdigest()
        response = client.rpc(
            "consume_rate_limit",
            {
                "p_scope": scope,
                "p_identifier_hash": identifier_hash,
                "p_limit": limit,
                "p_window_seconds": 86400,
            },
        ).execute()
        row = (response.data or [{}])[0]
        if not row.get("allowed", False):
            return False, f"{scope} limit exceeded; retry after {row.get('retry_after_seconds', 0)} seconds"
    return True, "All canonical checks passed"


def get_supabase_rate_limit_stats(ip_address: str, session_id: str) -> Dict[str, int]:
    """Read the current shared counters for the usage transparency endpoint."""
    from src.utils.supabase_client import create_client

    url = os.getenv("SUPABASE_URL", "").strip()
    key = supabase_server_key()
    if not url or not key:
        raise RuntimeError("Supabase rate limiting requires server credentials")
    client = create_client(url, key)
    counts = {}
    for scope, identifier, output_key in (
        ("ip_daily", ip_address, "ip_usage"),
        ("session_daily", session_id, "session_usage"),
    ):
        identifier_hash = hashlib.sha256(identifier.encode("utf-8")).hexdigest()
        response = client.table("rate_limit_windows").select(
            "request_count,window_started_at"
        ).eq("scope", scope).eq("identifier_hash", identifier_hash).limit(1).execute()
        row = (response.data or [{}])[0]
        started_at = row.get("window_started_at")
        if started_at:
            try:
                started = datetime.fromisoformat(str(started_at).replace("Z", "+00:00"))
                if started.tzinfo is None:
                    started = started.replace(tzinfo=timezone.utc)
                if started <= datetime.now(timezone.utc) - timedelta(days=1):
                    counts[output_key] = 0
                    continue
            except (TypeError, ValueError):
                logger.warning("invalid_rate_limit_window_timestamp scope=%s", scope)
        counts[output_key] = int(row.get("request_count", 0))
    return {
        **counts,
        "ip_limit": RATE_LIMITS["ip_daily"],
        "session_limit": RATE_LIMITS["session_daily"],
    }

def log_usage_attempt(
    ip_address: str,
    session_id: str,
    document_hash: str,
    email: str = None,
    user_agent: str = None,
    allowed: bool = True,
    reason: str = None,
    policy_fingerprint: str = None
):
    """Log usage attempt for monitoring and analytics."""
    log_data = {
        'ip_address': ip_address,
        'session_id': session_id,
        'document_hash': document_hash[:16] + '...',  # Truncate for privacy
        'email_domain': email.split('@')[1] if email and '@' in email else None,
        'user_agent': user_agent[:100] if user_agent else None,  # Truncate
        'allowed': allowed,
        'reason': reason,
        'timestamp': datetime.now().isoformat()
    }
    
    if allowed:
        logger.info(f"Usage allowed: {log_data}")
        
        # Record successful usage in database
        try:
            from src.utils.database_migration import record_usage_attempt
            record_usage_attempt(
                document_hash=document_hash,
                ip_address=ip_address,
                session_id=session_id,
                user_email=email,
                user_agent=user_agent,
                policy_fingerprint=policy_fingerprint,
                db_path=ANTI_ABUSE_DB_PATH
            )
        except ImportError:
            logger.warning("Database migration module not available, skipping database logging")
        except Exception as e:
            logger.error(f"Failed to record usage in database: {e}")
    else:
        logger.warning(f"Usage blocked: {log_data}")

def rate_limit_decorator(check_session: bool = True, check_ip: bool = True):
    """Decorator for applying rate limiting to endpoints."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Extract request from args (assuming FastAPI endpoint)
            request = None
            for arg in args:
                if hasattr(arg, 'client') and hasattr(arg, 'headers'):
                    request = arg
                    break
            
            if not request:
                # If we can't find request, allow the call
                return await func(*args, **kwargs)
            
            ip_address = get_client_ip(request)
            session_id = request.headers.get('X-Session-ID', 'unknown')
            
            # Check rate limits
            if check_ip:
                ip_allowed, ip_reason = check_ip_rate_limit(ip_address)
                if not ip_allowed:
                    from fastapi import HTTPException
                    raise HTTPException(status_code=429, detail=ip_reason)
            
            if check_session:
                session_allowed, session_reason = check_session_rate_limit(session_id)
                if not session_allowed:
                    from fastapi import HTTPException
                    raise HTTPException(status_code=429, detail=session_reason)
            
            return await func(*args, **kwargs)
        return wrapper
    return decorator

# Utility functions for getting current usage stats
def get_current_usage_stats(ip_address: str, session_id: str) -> Dict:
    """Get current usage statistics for monitoring."""
    stats = {
        'ip_usage': 0,
        'session_usage': 0,
        'ip_limit': RATE_LIMITS['ip_daily'],
        'session_limit': RATE_LIMITS['session_daily']
    }
    
    if redis_client:
        try:
            # Get IP usage
            ip_key = _get_redis_key('ip', ip_address)
            _cleanup_old_entries(ip_key, 24)
            stats['ip_usage'] = redis_client.zcard(ip_key)
            
            # Get session usage
            session_key = _get_redis_key('session', session_id)
            _cleanup_old_entries(session_key, 24)
            stats['session_usage'] = redis_client.zcard(session_key)
        except Exception:
            # CSO F5: generic error, never leak Redis connection details.
            logger.warning("Usage stats unavailable via Redis, falling back to in-memory")
    else:
        # Memory store fallback
        _cleanup_memory_store()
        
        ip_key = _get_memory_store_key('ip', ip_address)
        session_key = _get_memory_store_key('session', session_id)
        
        stats['ip_usage'] = len(_memory_store.get(ip_key, []))
        stats['session_usage'] = len(_memory_store.get(session_key, []))
    
    return stats

# Initialize disposable email domains from environment if provided
def load_additional_disposable_domains():
    """Load additional disposable email domains from environment."""
    additional_domains = os.getenv('ADDITIONAL_DISPOSABLE_DOMAINS', '')
    if additional_domains:
        domains = [domain.strip() for domain in additional_domains.split(',')]
        DISPOSABLE_EMAIL_DOMAINS.update(domains)
        logger.info(f"Loaded {len(domains)} additional disposable email domains")

# Load additional domains on import
load_additional_disposable_domains()
