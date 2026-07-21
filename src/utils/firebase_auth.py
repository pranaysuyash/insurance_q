"""Historical Firebase authentication adapter.

Supabase Auth is the canonical identity provider. This module remains only as
an explicit migration compatibility boundary and is intentionally lazy-imported
so the production image does not carry a second auth SDK or identity path.
"""

import os
import json
import base64
from fastapi import HTTPException


class FirebaseCompatibilityUnavailable(RuntimeError):
    """Raised when a legacy Firebase path is invoked without its dependency."""


def _firebase_modules():
    try:
        import firebase_admin
        from firebase_admin import auth, credentials
    except ImportError as error:  # pragma: no cover - legacy deployment only
        raise FirebaseCompatibilityUnavailable(
            "Firebase is not a production dependency; use Supabase Auth"
        ) from error
    return firebase_admin, auth, credentials

# Initialize Firebase app (should be called once in app startup)
def init_firebase():
    firebase_admin, _, credentials = _firebase_modules()
    if not firebase_admin._apps:
        # Try base64 encoded service account first (for production)
        firebase_b64 = os.getenv("FIREBASE_SERVICE_ACCOUNT_B64")
        if firebase_b64:
            try:
                # Decode base64 and create temporary file
                service_account_json = base64.b64decode(firebase_b64).decode('utf-8')
                service_account_dict = json.loads(service_account_json)
                
                # Initialize with dictionary
                cred = credentials.Certificate(service_account_dict)
                firebase_admin.initialize_app(cred)
                print("✅ Firebase initialized with base64 service account")
                return
            except Exception as e:
                print(f"⚠️ Failed to initialize Firebase with base64 service account: {e}")
        
        # Fallback to file path (for local development)
        key_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "/app/serviceAccountKey.json")
        if os.path.isfile(key_path):
            try:
                cred = credentials.Certificate(key_path)
                firebase_admin.initialize_app(cred)
                print("✅ Firebase initialized with service account file")
                return
            except Exception as e:
                print(f"⚠️ Failed to initialize Firebase with file: {e}")
        
        # If both methods fail, log and return — auth endpoints will be
        # unavailable but the rest of the API works. This is intentional:
        # the mobile app currently operates without Firebase auth, and
        # failing hard here would block startup for no benefit.
        print("⚠️ No Firebase service account configured. Auth endpoints disabled.")
        return False

    return True

# Verify Firebase ID token and return decoded claims
def verify_firebase_token(id_token: str):
    _, auth, _ = _firebase_modules()
    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired Firebase token")
