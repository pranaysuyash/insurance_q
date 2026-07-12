from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, PlainTextResponse, Response
import uvicorn
import os

app = FastAPI(title="CoverWise Static Frontend")

# Get the directory containing this file
current_dir = os.path.dirname(os.path.abspath(__file__))

# Mount the static files directory
app.mount("/static", StaticFiles(directory=os.path.join(current_dir, "static")), name="static")

@app.get("/")
async def read_root():
    """Serve the main HTML page."""
    return FileResponse(os.path.join(current_dir, "index.html"))


@app.get("/robots.txt")
async def robots_txt(request: Request):
    site_url = str(request.base_url).rstrip("/")
    content = "\n".join(
        [
            "User-agent: *",
            "Allow: /",
            f"Sitemap: {site_url}/sitemap.xml",
            "",
        ]
    )
    return PlainTextResponse(content, media_type="text/plain")


@app.get("/sitemap.xml")
async def sitemap_xml(request: Request):
    site_url = str(request.base_url).rstrip("/")
    xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>{site_url}/</loc>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
"""
    return Response(content=xml, media_type="application/xml")


@app.api_route("/favicon.ico", methods=["GET", "HEAD"])
async def favicon():
    return FileResponse(os.path.join(current_dir, "static", "favicon.ico"))

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
