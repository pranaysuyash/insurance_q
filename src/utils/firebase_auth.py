import firebase_admin
from firebase_admin import auth, credentials
from fastapi import HTTPException

# Initialize Firebase app (should be called once in app startup)
def init_firebase():
    if not firebase_admin._apps:
        import os
        key_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "/app/serviceAccountKey.json")
        if os.path.isfile(key_path):
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
        else:
            raise FileNotFoundError(f"No service account file at {key_path}")

# Verify Firebase ID token and return decoded claims
def verify_firebase_token(id_token: str):
    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired Firebase token")
