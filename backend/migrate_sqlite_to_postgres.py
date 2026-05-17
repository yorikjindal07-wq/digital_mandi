import os
from pathlib import Path

from sqlalchemy import create_engine, select, text
from sqlalchemy.orm import Session, sessionmaker

from app.api.db.models import Base, DiseaseReport, OutbreakAlert, User


def _normalize_postgres_url(raw_url: str) -> str:
    cleaned = raw_url.strip()
    if not cleaned:
        raise ValueError("DATABASE_URL is required and must point to Render PostgreSQL.")
    if cleaned.startswith("postgres://"):
        return cleaned.replace("postgres://", "postgresql+psycopg2://", 1)
    if cleaned.startswith("postgresql://"):
        return cleaned.replace("postgresql://", "postgresql+psycopg2://", 1)
    if not cleaned.startswith("postgresql+psycopg2://"):
        raise ValueError("DATABASE_URL must be a PostgreSQL connection string.")
    return cleaned


def _resolve_sqlite_url() -> str:
    sqlite_path = os.getenv("SQLITE_PATH", "").strip()
    if sqlite_path:
        resolved_path = Path(sqlite_path).expanduser().resolve()
    else:
        resolved_path = Path(__file__).resolve().parent / "data" / "digital_mandi.db"
    if not resolved_path.exists():
        raise FileNotFoundError(
            f"SQLite database file was not found at {resolved_path}. "
            "Set SQLITE_PATH if your local database lives elsewhere.",
        )
    return f"sqlite:///{resolved_path.as_posix()}"


def _redact_database_url(database_url: str) -> str:
    prefix, separator, remainder = database_url.partition("://")
    if not separator:
        return database_url

    credentials, at_sign, host_part = remainder.partition("@")
    if not at_sign:
        return f"{prefix}://{host_part}"

    username, colon, _password = credentials.partition(":")
    safe_credentials = f"{username}:***" if colon else username
    return f"{prefix}://{safe_credentials}@{host_part}"


def _copy_users(source_session: Session, target_session: Session) -> int:
    rows = source_session.scalars(select(User).order_by(User.id)).all()
    copied = 0
    for row in rows:
        if target_session.get(User, row.id) is not None:
            continue
        target_session.add(
            User(
                id=row.id,
                email=row.email,
                password_hash=row.password_hash,
                is_active=row.is_active,
                created_at=row.created_at,
                last_login_at=row.last_login_at,
            ),
        )
        copied += 1
    return copied


def _copy_reports(source_session: Session, target_session: Session) -> int:
    rows = source_session.scalars(select(DiseaseReport).order_by(DiseaseReport.id)).all()
    copied = 0
    for row in rows:
        if target_session.get(DiseaseReport, row.id) is not None:
            continue
        target_session.add(
            DiseaseReport(
                id=row.id,
                crop=row.crop,
                disease=row.disease,
                confidence=row.confidence,
                region=row.region,
                created_at=row.created_at,
                device_id=row.device_id,
            ),
        )
        copied += 1
    return copied


def _copy_alerts(source_session: Session, target_session: Session) -> int:
    rows = source_session.scalars(select(OutbreakAlert).order_by(OutbreakAlert.id)).all()
    copied = 0
    for row in rows:
        if target_session.get(OutbreakAlert, row.id) is not None:
            continue
        target_session.add(
            OutbreakAlert(
                id=row.id,
                disease=row.disease,
                region=row.region,
                count=row.count,
                severity=row.severity,
                created_at=row.created_at,
                is_active=row.is_active,
            ),
        )
        copied += 1
    return copied


def _sync_postgres_sequence(target_session: Session, table_name: str) -> None:
    target_session.execute(
        text(
            """
            SELECT setval(
                pg_get_serial_sequence(:table_name, 'id'),
                COALESCE((SELECT MAX(id) FROM """ + table_name + """), 1),
                (SELECT COUNT(*) > 0 FROM """ + table_name + """)
            )
            """,
        ),
        {"table_name": table_name},
    )


def main() -> None:
    postgres_url = _normalize_postgres_url(os.getenv("DATABASE_URL", ""))
    sqlite_url = _resolve_sqlite_url()

    print(f"Source SQLite: {sqlite_url}")
    print(f"Target Postgres: {_redact_database_url(postgres_url)}")

    sqlite_engine = create_engine(sqlite_url)
    postgres_engine = create_engine(postgres_url, pool_pre_ping=True)

    Base.metadata.create_all(bind=postgres_engine)

    SourceSession = sessionmaker(bind=sqlite_engine, autoflush=False, autocommit=False)
    TargetSession = sessionmaker(bind=postgres_engine, autoflush=False, autocommit=False)

    with SourceSession() as source_session, TargetSession() as target_session:
        copied_users = _copy_users(source_session, target_session)
        copied_reports = _copy_reports(source_session, target_session)
        copied_alerts = _copy_alerts(source_session, target_session)
        _sync_postgres_sequence(target_session, "users")
        _sync_postgres_sequence(target_session, "disease_reports")
        _sync_postgres_sequence(target_session, "outbreak_alerts")
        target_session.commit()

    print("Migration complete.")
    print(f"Users copied: {copied_users}")
    print(f"Disease reports copied: {copied_reports}")
    print(f"Outbreak alerts copied: {copied_alerts}")


if __name__ == "__main__":
    main()
