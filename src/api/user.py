from fastapi import APIRouter, Depends, Header
from src.utils.firebase_auth import verify_firebase_token
from src.models.user import User

router = APIRouter(prefix="/user", tags=["user"])

# Dependency to get current user from Firebase token
def get_current_user(authorization: str = Header(...)) -> User:
    token = authorization.replace("Bearer ", "")
    claims = verify_firebase_token(token)
    return User(
        uid=claims["uid"],
        email=claims.get("email"),
        phone=claims.get("phone_number"),
        display_name=claims.get("name")
    )

@router.get("/profile", response_model=User)
def get_profile(current_user: User = Depends(get_current_user)):
    return current_user
