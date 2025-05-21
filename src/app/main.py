from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.api.user import router as user_router
from src.api.family import router as family_router
from src.api.policy import router as policy_router
from src.api.document import router as document_router
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
app.include_router(policy_router)
app.include_router(document_router)

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/documents")
def get_test_documents():
    """Test endpoint for mobile app to fetch documents without authentication."""
    return {
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
        "total": 2,
        "page": 1,
        "limit": 10,
        "total_pages": 1
    }
