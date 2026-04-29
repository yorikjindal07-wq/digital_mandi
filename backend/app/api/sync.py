from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.db.database import get_db
from app.api.db.models import DiseaseReport
from app.api.report import PredictionPayload

router = APIRouter()


@router.get("/sync/status")
def sync_status() -> dict[str, str]:
    return {
        "status": "ok",
        "server_time": datetime.utcnow().isoformat(),
    }


@router.post("/sync/bulk")
def sync_bulk(
    reports: list[PredictionPayload],
    db: Session = Depends(get_db),
) -> dict[str, int | str]:
    rows = []
    for report in reports:
        row = DiseaseReport(
            crop=report.crop,
            disease=report.disease,
            confidence=report.confidence,
            region=report.region,
            device_id=report.device_id,
        )
        if report.created_at is not None:
            row.created_at = report.created_at
        rows.append(row)

    if rows:
        db.add_all(rows)
        db.commit()

    return {
        "message": f"Synced {len(rows)} reports",
        "saved": len(rows),
    }
