from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field, field_validator
from sqlalchemy.orm import Session

from app.api.db import models as db_models
from app.api.db.database import get_db
from app.security import (
    PASSWORD_MIN_LENGTH,
    authenticate_user,
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
    hash_password,
    normalize_email,
    validate_password_length,
)

router = APIRouter()


class AuthRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if len(value) < PASSWORD_MIN_LENGTH:
            raise ValueError(
                f"Password must be at least {PASSWORD_MIN_LENGTH} characters",
            )
        validate_password_length(value)
        return value


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., min_length=20, max_length=4096)


class UserResponse(BaseModel):
    id: int
    email: str
    is_active: bool
    created_at: datetime
    last_login_at: datetime | None = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    access_token_expires_at: datetime
    refresh_token_expires_at: datetime
    user: UserResponse


def _build_user_response(user: db_models.User) -> UserResponse:
    return UserResponse(
        id=user.id,
        email=user.email,
        is_active=user.is_active,
        created_at=user.created_at,
        last_login_at=user.last_login_at,
    )


def _issue_tokens(user: db_models.User) -> TokenResponse:
    access_token, access_expires_at = create_access_token(user.email)
    refresh_token, refresh_expires_at = create_refresh_token(user.email)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        access_token_expires_at=access_expires_at,
        refresh_token_expires_at=refresh_expires_at,
        user=_build_user_response(user),
    )


@router.post("/auth/register", response_model=TokenResponse, status_code=201)
def register(req: AuthRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = normalize_email(req.email)
    existing_user = (
        db.query(db_models.User)
        .filter(db_models.User.email == email)
        .first()
    )
    if existing_user is not None:
        raise HTTPException(status_code=409, detail="An account already exists for this email.")

    user = db_models.User(
        email=email,
        password_hash=hash_password(req.password),
        is_active=True,
        last_login_at=datetime.now(timezone.utc),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _issue_tokens(user)


@router.post("/auth/login", response_model=TokenResponse)
def login(req: AuthRequest, db: Session = Depends(get_db)) -> TokenResponse:
    user = authenticate_user(db, email=req.email, password=req.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
        )
    if not user.is_active:
        raise HTTPException(status_code=403, detail="User account is disabled.")

    user.last_login_at = datetime.now(timezone.utc)
    db.add(user)
    db.commit()
    db.refresh(user)
    return _issue_tokens(user)


@router.post("/auth/refresh", response_model=TokenResponse)
def refresh(req: RefreshRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = decode_token(req.refresh_token, expected_type="refresh")
    user = (
        db.query(db_models.User)
        .filter(db_models.User.email == email)
        .first()
    )
    if user is None:
        raise HTTPException(status_code=401, detail="User not found.")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="User account is disabled.")

    return _issue_tokens(user)


@router.get("/auth/me", response_model=UserResponse)
def me(current_user: db_models.User = Depends(get_current_user)) -> UserResponse:
    return _build_user_response(current_user)
