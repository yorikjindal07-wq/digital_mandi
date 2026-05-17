import asyncio
import logging
import os
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

from app.api.auth import router as auth_router
from app.api.chat import router as chat_router
from app.api.db import models as db_models
from app.api.db.database import (
    DATABASE_URL,
    engine,
    get_database_backend_name,
    get_redacted_database_url,
    verify_database_connection,
)
from app.api.report import router as report_router
from app.api.sync import router as sync_router
from app.api.treatments import router as treatments_router
from app.api.weather import router as weather_router
from app.security import (
    ADMIN_API_TOKEN,
    JWT_REFRESH_SECRET_KEY,
    JWT_SECRET_KEY,
    RATE_LIMIT_WINDOW_SECONDS,
    classify_rate_limit_bucket,
    get_request_ip,
    rate_limiter,
)
from app.services.treatment_api_service import refresh_treatments_json, should_refresh

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


def _log_startup_security_warnings() -> None:
    cors_raw_value = os.getenv("CORS_ALLOW_ORIGINS", "").strip()

    if not JWT_SECRET_KEY:
        logger.warning("JWT_SECRET_KEY is missing. User login will not work securely.")
    if not JWT_REFRESH_SECRET_KEY:
        logger.warning(
            "JWT_REFRESH_SECRET_KEY is missing. Refresh tokens will fall back to the access-token secret.",
        )
    if not ADMIN_API_TOKEN:
        logger.warning("ADMIN_API_TOKEN is missing. Admin refresh protection is incomplete.")
    if cors_raw_value == "*":
        logger.warning(
            "CORS_ALLOW_ORIGINS is set to '*'. Restrict it to your real web domain before production.",
        )
    if not cors_raw_value:
        logger.info(
            "CORS_ALLOW_ORIGINS is empty. This is fine for mobile-only usage, but set it explicitly for any web frontend.",
        )
    if DATABASE_URL.startswith("sqlite"):
        logger.warning(
            "Backend is using SQLite. This is fine for local development, but Render production should use DATABASE_URL from Render Postgres.",
        )
    logger.info(
        "Configured database backend=%s url=%s",
        get_database_backend_name(),
        get_redacted_database_url(),
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    verify_database_connection()
    db_models.Base.metadata.create_all(bind=engine)
    if should_refresh():
        asyncio.create_task(refresh_treatments_json())
    yield


app = FastAPI(
    title="Digital Mandi API",
    version="2.0.0",
    lifespan=lifespan,
)

_log_startup_security_warnings()

allowed_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ALLOW_ORIGINS", "").split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=[
        "Accept",
        "Authorization",
        "Content-Type",
        "X-Admin-Token",
        "X-Client-Token",
    ],
)

app.include_router(auth_router, prefix="/api/v1", tags=["Auth"])
app.include_router(chat_router, prefix="/api/v1", tags=["Chat"])
app.include_router(weather_router, prefix="/api/v1", tags=["Weather"])
app.include_router(treatments_router, prefix="/api/v1", tags=["Treatments"])
app.include_router(report_router, tags=["Reports"])
app.include_router(sync_router, tags=["Sync"])


@app.middleware("http")
async def rate_limit_and_log_requests(request: Request, call_next):
    client_ip = get_request_ip(request)
    bucket_name, limit = classify_rate_limit_bucket(request)

    if bucket_name is not None:
        decision = rate_limiter.allow(key=f"{bucket_name}:{client_ip}", limit=limit)
        if not decision.allowed:
            logger.warning(
                "Rate limit blocked request ip=%s method=%s path=%s bucket=%s retry_after=%ss",
                client_ip,
                request.method,
                request.url.path,
                bucket_name,
                decision.retry_after_seconds,
            )
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests"},
                headers={
                    "Retry-After": str(decision.retry_after_seconds),
                    "X-RateLimit-Limit": str(decision.limit),
                    "X-RateLimit-Window": str(RATE_LIMIT_WINDOW_SECONDS),
                },
            )

    started_at = time.perf_counter()
    response = await call_next(request)
    duration_ms = (time.perf_counter() - started_at) * 1000

    logger.info(
        "Request method=%s path=%s status=%s ip=%s duration_ms=%.1f",
        request.method,
        request.url.path,
        response.status_code,
        client_ip,
        duration_ms,
    )
    return response


@app.get("/")
def root() -> dict[str, str]:
    return {"service": "Digital Mandi API v2.0", "status": "running"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}


@app.post("/api/v1/treatments/refresh")
async def force_refresh(
    x_admin_token: str | None = Header(default=None),
) -> dict[str, str]:
    if not ADMIN_API_TOKEN:
        raise HTTPException(status_code=503, detail="ADMIN_API_TOKEN not configured")
    if x_admin_token != ADMIN_API_TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden")
    await refresh_treatments_json()
    return {"message": "Treatments refreshed"}
