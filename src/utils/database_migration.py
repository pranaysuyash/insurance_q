"""
Database migration script for anti-abuse system.
Creates tables for usage tracking, blocked domains, and insurance companies.
"""

import sqlite3
import logging
from datetime import datetime
import os

logger = logging.getLogger(__name__)

def create_anti_abuse_tables(db_path: str = "insurance_app.db"):
    """Create anti-abuse system tables in SQLite database."""
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Usage tracking table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS usage_tracking (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                policy_fingerprint TEXT,
                document_hash TEXT NOT NULL,
                user_email TEXT,
                ip_address TEXT,
                session_id TEXT,
                user_agent TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                extracted_metadata TEXT,  -- JSON as TEXT in SQLite
                usage_tier TEXT DEFAULT 'free'
            )
        """)
        
        # Create indexes for performance
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_document_hash 
            ON usage_tracking (document_hash)
        """)
        
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_ip_date 
            ON usage_tracking (ip_address, DATE(created_at))
        """)
        
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_session_date 
            ON usage_tracking (session_id, DATE(created_at))
        """)
        
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_policy_fingerprint_month 
            ON usage_tracking (policy_fingerprint, strftime('%Y-%m', created_at))
        """)
        
        # Blocked domains table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS blocked_domains (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                domain TEXT UNIQUE NOT NULL,
                reason TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Known insurance companies table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS insurance_companies (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                aliases TEXT,  -- JSON array as TEXT
                verified BOOLEAN DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Insert some initial disposable email domains
        disposable_domains = [
            ('10minutemail.com', 'Known disposable email service'),
            ('tempmail.org', 'Known disposable email service'),
            ('guerrillamail.com', 'Known disposable email service'),
            ('mailinator.com', 'Known disposable email service'),
            ('throwaway.email', 'Known disposable email service'),
            ('temp-mail.org', 'Known disposable email service'),
            ('yopmail.com', 'Known disposable email service'),
            ('maildrop.cc', 'Known disposable email service')
        ]
        
        cursor.executemany("""
            INSERT OR IGNORE INTO blocked_domains (domain, reason) 
            VALUES (?, ?)
        """, disposable_domains)
        
        # Insert some known insurance companies
        insurance_companies = [
            ('State Farm', '["State Farm Insurance", "State Farm Mutual"]', 1),
            ('Geico', '["Government Employees Insurance Company"]', 1),
            ('Progressive', '["Progressive Insurance"]', 1),
            ('Allstate', '["Allstate Insurance"]', 1),
            ('USAA', '["United Services Automobile Association"]', 1),
            ('Liberty Mutual', '["Liberty Mutual Insurance"]', 1),
            ('Farmers', '["Farmers Insurance"]', 1),
            ('Nationwide', '["Nationwide Insurance"]', 1),
            ('American Family', '["American Family Insurance"]', 1),
            ('Travelers', '["Travelers Insurance"]', 1)
        ]
        
        cursor.executemany("""
            INSERT OR IGNORE INTO insurance_companies (name, aliases, verified) 
            VALUES (?, ?, ?)
        """, insurance_companies)
        
        conn.commit()
        conn.close()
        
        logger.info("Anti-abuse database tables created successfully")
        return True
        
    except Exception as e:
        logger.error(f"Failed to create anti-abuse tables: {e}")
        return False

def record_usage_attempt(
    document_hash: str,
    ip_address: str,
    session_id: str,
    user_email: str = None,
    user_agent: str = None,
    policy_fingerprint: str = None,
    extracted_metadata: str = None,
    db_path: str = "insurance_app.db"
):
    """Record a usage attempt in the database."""
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO usage_tracking 
            (policy_fingerprint, document_hash, user_email, ip_address, 
             session_id, user_agent, extracted_metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            policy_fingerprint,
            document_hash,
            user_email,
            ip_address,
            session_id,
            user_agent,
            extracted_metadata
        ))
        
        conn.commit()
        conn.close()
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to record usage attempt: {e}")
        return False

def check_document_hash_exists_db(document_hash: str, db_path: str = "insurance_app.db") -> bool:
    """Check if document hash exists in database."""
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT COUNT(*) FROM usage_tracking 
            WHERE document_hash = ?
        """, (document_hash,))
        
        count = cursor.fetchone()[0]
        conn.close()
        
        return count > 0
        
    except Exception as e:
        logger.error(f"Failed to check document hash: {e}")
        return False

def get_usage_count_by_ip(ip_address: str, hours: int = 24, db_path: str = "insurance_app.db") -> int:
    """Get usage count for IP address within specified hours."""
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT COUNT(*) FROM usage_tracking 
            WHERE ip_address = ? 
            AND created_at > datetime('now', '-{} hours')
        """.format(hours), (ip_address,))
        
        count = cursor.fetchone()[0]
        conn.close()
        
        return count
        
    except Exception as e:
        logger.error(f"Failed to get IP usage count: {e}")
        return 0

def get_usage_count_by_session(session_id: str, hours: int = 24, db_path: str = "insurance_app.db") -> int:
    """Get usage count for session ID within specified hours."""
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT COUNT(*) FROM usage_tracking 
            WHERE session_id = ? 
            AND created_at > datetime('now', '-{} hours')
        """.format(hours), (session_id,))
        
        count = cursor.fetchone()[0]
        conn.close()
        
        return count
        
    except Exception as e:
        logger.error(f"Failed to get session usage count: {e}")
        return 0

def get_usage_count_by_policy(policy_fingerprint: str, days: int = 30, db_path: str = "insurance_app.db") -> int:
    """Get usage count for policy fingerprint within specified days."""
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT COUNT(*) FROM usage_tracking 
            WHERE policy_fingerprint = ? 
            AND created_at > datetime('now', '-{} days')
        """.format(days), (policy_fingerprint,))
        
        count = cursor.fetchone()[0]
        conn.close()
        
        return count
        
    except Exception as e:
        logger.error(f"Failed to get policy usage count: {e}")
        return 0

def is_domain_blocked(domain: str, db_path: str = "insurance_app.db") -> bool:
    """Check if email domain is blocked."""
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT COUNT(*) FROM blocked_domains 
            WHERE domain = ?
        """, (domain.lower(),))
        
        count = cursor.fetchone()[0]
        conn.close()
        
        return count > 0
        
    except Exception as e:
        logger.error(f"Failed to check blocked domain: {e}")
        return False

def get_usage_analytics(days: int = 7, db_path: str = "insurance_app.db") -> dict:
    """Get usage analytics for monitoring."""
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Total usage in period
        cursor.execute("""
            SELECT COUNT(*) FROM usage_tracking 
            WHERE created_at > datetime('now', '-{} days')
        """.format(days))
        total_usage = cursor.fetchone()[0]
        
        # Unique IPs
        cursor.execute("""
            SELECT COUNT(DISTINCT ip_address) FROM usage_tracking 
            WHERE created_at > datetime('now', '-{} days')
        """.format(days))
        unique_ips = cursor.fetchone()[0]
        
        # Unique sessions
        cursor.execute("""
            SELECT COUNT(DISTINCT session_id) FROM usage_tracking 
            WHERE created_at > datetime('now', '-{} days')
        """.format(days))
        unique_sessions = cursor.fetchone()[0]
        
        # Top domains
        cursor.execute("""
            SELECT 
                SUBSTR(user_email, INSTR(user_email, '@') + 1) as domain,
                COUNT(*) as count
            FROM usage_tracking 
            WHERE user_email IS NOT NULL 
            AND created_at > datetime('now', '-{} days')
            GROUP BY domain
            ORDER BY count DESC
            LIMIT 10
        """.format(days))
        top_domains = cursor.fetchall()
        
        conn.close()
        
        return {
            "period_days": days,
            "total_usage": total_usage,
            "unique_ips": unique_ips,
            "unique_sessions": unique_sessions,
            "top_email_domains": [{"domain": d[0], "count": d[1]} for d in top_domains],
            "generated_at": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Failed to get usage analytics: {e}")
        return {}

if __name__ == "__main__":
    # Run migration
    success = create_anti_abuse_tables()
    if success:
        print("✅ Anti-abuse database tables created successfully")
    else:
        print("❌ Failed to create anti-abuse database tables") 