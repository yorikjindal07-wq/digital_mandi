import logging, asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from app.api.db.database import engine
from app.api.db import models as db_models
from app.api.chat import router as chat_router
from app.services.treatment_api_service import refresh_treatments_json, should_refresh

logging.basicConfig(level=logging.INFO, format="%(asctime)s — %(levelname)s — %(message)s")
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    db_models.Base.metadata.create_all(bind=engine)
    if should_refresh():
        asyncio.create_task(refresh_treatments_json())
    yield

app = FastAPI(title="Digital Mandi API", version="2.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(chat_router, prefix="/api/v1", tags=["Chat"])

@app.get("/")
def root(): return {"service": "Digital Mandi API v2.0", "status": "running"}

@app.get("/health")
def health(): return {"status": "healthy"}

@app.post("/api/v1/treatments/refresh")
async def force_refresh():
    await refresh_treatments_json()
    return {"message": "Treatments refreshed"}