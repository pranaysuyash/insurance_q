from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.api.user import router as user_router
from src.api.family import router as family_router
from src.utils.firebase_auth import init_firebase

app = FastAPI(title="Insurance Policy Parser & QA API", version="1.0.0")

# CORS setup (allow all for now, restrict in prod)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup_event():
    init_firebase()

app.include_router(user_router)
app.include_router(family_router)

@app.get("/health")
def health_check():
    return {"status": "ok"}
