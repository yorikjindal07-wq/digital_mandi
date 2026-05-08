import logging
import os
import secrets
import threading
import time
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.api.db import models as db_models
from app.api.db.database import get_db

logger = logging.getLogger(__name__)

BACKEND_API_TOKEN = os.getenv("BACKEND_API_TOKEN", "")
ADMIN_API_TOKEN = os.getenv("ADMIN_API_TOKEN", "")
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "")
JWT_REFRESH_SECRET_KEY = os.getenv("JWT_REFRESH_SECRET_KEY", JWT_SECRET_KEY)
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "14"))
PASSWORD_MIN_LENGTH = int(os.getenv("PASSWORD_MIN_LENGTH", "8"))
RATE_LIMIT_GENERAL_PER_MINUTE = int(os.getenv("RATE_LIMIT_GENERAL_PER_MINUTE", "120"))
RATE_LIMIT_WRITE_PER_MINUTE = int(os.getenv("RATE_LIMIT_WRITE_PER_MINUTE", "30"))
RATE_LIMIT_CHAT_PER_MINUTE = int(os.getenv("RATE_LIMIT_CHAT_PER_MINUTE", "20"))
RATE_LIMIT_AUTH_PER_MINUTE = int(os.getenv("RATE_LIMIT_AUTH_PER_MINUTE", "10"))
RATE_LIMIT_WINDOW_SECONDS = 60

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
http_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class RateLimitDecision:
    allowed: bool
    limit: int
    retry_after_seconds: int


class InMemoryRateLimiter:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._buckets: dict[str, deque[float]] = {}

    def allow(
        self,
        *,
        key: str,
        limit: int,
        window_seconds: int = RATE_LIMIT_WINDOW_SECONDS,
    ) -> RateLimitDecision:
        now = time.monotonic()

        with self._lock:
            bucket = self._buckets.setdefault(key, deque())
            cutoff = now - window_seconds

            while bucket and bucket[0] <= cutoff:
                bucket.popleft()

            if len(bucket) >= limit:
                retry_after = max(1, int(window_seconds - (now - bucket[0])))
                return RateLimitDecision(
                    allowed=False,
                    limit=limit,
                    retry_after_seconds=retry_after,
                )

            bucket.append(now)

            if not bucket:
                self._buckets.pop(key, None)

            return RateLimitDecision(
                allowed=True,
                limit=limit,
                retry_after_seconds=0,
            )


rate_limiter = InMemoryRateLimiter()


def get_request_ip(request: Request) -> str:
    forwarded_for = request.headers.get("x-forwarded-for", "")
    if forwarded_for:
        first_ip = forwarded_for.split(",")[0].strip()
        if first_ip:
            return first_ip

    real_ip = request.headers.get("x-real-ip", "").strip()
    if real_ip:
        return real_ip

    return request.client.host if request.client else "unknown"


def classify_rate_limit_bucket(request: Request) -> tuple[str | None, int]:
    path = request.url.path
    method = request.method.upper()

    if path in {"/", "/health"}:
        return None, 0

    if path.startswith("/api/v1/auth"):
        return "auth", RATE_LIMIT_AUTH_PER_MINUTE

    if path.startswith("/api/v1/chat"):
        return "chat", RATE_LIMIT_CHAT_PER_MINUTE

    if method == "POST" and (
        path.startswith("/reports")
        or path.startswith("/report")
        or path.startswith("/sync/")
        or path.startswith("/api/v1/treatments/refresh")
    ):
        return "write", RATE_LIMIT_WRITE_PER_MINUTE

    return "general", RATE_LIMIT_GENERAL_PER_MINUTE


def require_backend_api_token(
    x_client_token: str | None = Header(default=None),
) -> None:
    if not BACKEND_API_TOKEN:
        raise HTTPException(
            status_code=503,
            detail="BACKEND_API_TOKEN not configured on backend.",
        )

    if not x_client_token or not secrets.compare_digest(
        x_client_token,
        BACKEND_API_TOKEN,
    ):
        raise HTTPException(status_code=403, detail="Forbidden")


def normalize_email(email: str) -> str:
    return email.strip().lower()


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def _ensure_jwt_configured() -> None:
    if not JWT_SECRET_KEY or not JWT_REFRESH_SECRET_KEY:
        raise HTTPException(
            status_code=503,
            detail="JWT secrets are not configured on the backend.",
        )


def _create_signed_token(
    *,
    subject: str,
    token_type: str,
    secret_key: str,
    expires_delta: timedelta,
) -> tuple[str, datetime]:
    now = datetime.now(timezone.utc)
    expires_at = now + expires_delta
    payload = {
        "sub": subject,
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    token = jwt.encode(payload, secret_key, algorithm=JWT_ALGORITHM)
    return token, expires_at


def create_access_token(subject: str) -> tuple[str, datetime]:
    _ensure_jwt_configured()
    return _create_signed_token(
        subject=subject,
        token_type="access",
        secret_key=JWT_SECRET_KEY,
        expires_delta=timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
    )


def create_refresh_token(subject: str) -> tuple[str, datetime]:
    _ensure_jwt_configured()
    return _create_signed_token(
        subject=subject,
        token_type="refresh",
        secret_key=JWT_REFRESH_SECRET_KEY,
        expires_delta=timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
    )


def decode_token(token: str, *, expected_type: str) -> str:
    secret_key = JWT_REFRESH_SECRET_KEY if expected_type == "refresh" else JWT_SECRET_KEY
    _ensure_jwt_configured()

    try:
        payload = jwt.decode(token, secret_key, algorithms=[JWT_ALGORITHM])
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token.",
        ) from exc

    subject = payload.get("sub")
    token_type = payload.get("type")
    if not isinstance(subject, str) or not subject.strip() or token_type != expected_type:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload.",
        )

    return normalize_email(subject)


def authenticate_user(
    db: Session,
    *,
    email: str,
    password: str,
) -> db_models.User | None:
    normalized_email = normalize_email(email)
    user = (
        db.query(db_models.User)
        .filter(db_models.User.email == normalized_email)
        .first()
    )
    if user is None or not verify_password(password, user.password_hash):
        return None
    return user


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(http_bearer),
    db: Session = Depends(get_db),
) -> db_models.User:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = decode_token(credentials.credentials, expected_type="access")
    user = (
        db.query(db_models.User)
        .filter(db_models.User.email == email)
        .first()
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled.",
        )
    return user
