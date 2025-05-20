import firebase_admin
from firebase_admin import auth, credentials
from fastapi import HTTPException

# Initialize Firebase app (should be called once in app startup)
def init_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate("path/to/serviceAccountKey.json")  # Set path in env/config
        firebase_admin.initialize_app(cred)

# Verify Firebase ID token and return decoded claims
def verify_firebase_token(id_token: str):
    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired Firebase token")
