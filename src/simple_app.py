from fastapi import FastAPI

app = FastAPI(title="Simple Test API")

@app.get("/")
async def root():
    return {"message": "Hello from Azure!", "status": "ok"}

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "simple-test"}

@app.get("/test")
async def test():
    return {"test": "working", "deployment": "success"} 