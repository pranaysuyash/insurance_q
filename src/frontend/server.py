from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import uvicorn
import os

app = FastAPI(title="Insurance Policy Parser Frontend")

# Get the directory containing this file
current_dir = os.path.dirname(os.path.abspath(__file__))

# Mount the static files directory
app.mount("/static", StaticFiles(directory=current_dir), name="static")

@app.get("/")
async def read_root():
    """Serve the main HTML page."""
    return FileResponse(os.path.join(current_dir, "index.html"))

def start_server():
    """Start the frontend server."""
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
        log_level="info"
    )

if __name__ == "__main__":
    start_server() 