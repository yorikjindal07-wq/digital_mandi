from collections.abc import Generator
import os
from pathlib import Path

from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker


def _build_database_url() -> str:
    database_url = os.getenv("DATABASE_URL", "").strip()
    if database_url:
        if database_url.startswith("postgres://"):
            return database_url.replace("postgres://", "postgresql+psycopg2://", 1)
        return database_url

    sqlite_path = os.getenv("SQLITE_PATH", "").strip()
    if sqlite_path:
        resolved_path = Path(sqlite_path).expanduser().resolve()
    else:
        resolved_path = Path(__file__).resolve().parents[3] / "data" / "digital_mandi.db"

    resolved_path.parent.mkdir(parents=True, exist_ok=True)
    return f"sqlite:///{resolved_path.as_posix()}"


DATABASE_URL = _build_database_url()
CONNECT_ARGS = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
IS_SQLITE = DATABASE_URL.startswith("sqlite")
IS_POSTGRES = DATABASE_URL.startswith("postgresql")

engine = create_engine(
    DATABASE_URL,
    connect_args=CONNECT_ARGS,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_database_backend_name() -> str:
    if IS_POSTGRES:
        return "postgresql"
    if IS_SQLITE:
        return "sqlite"
    return "unknown"


def get_redacted_database_url() -> str:
    if IS_SQLITE:
        return DATABASE_URL

    prefix, separator, remainder = DATABASE_URL.partition("://")
    if not separator:
        return DATABASE_URL

    credentials, at_sign, host_part = remainder.partition("@")
    if not at_sign:
        return f"{prefix}://{host_part}"

    username, colon, _password = credentials.partition(":")
    safe_credentials = f"{username}:***" if colon else username
    return f"{prefix}://{safe_credentials}@{host_part}"


def verify_database_connection() -> None:
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))
