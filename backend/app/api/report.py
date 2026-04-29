from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.db.database import get_db
from app.api.db.models import DiseaseReport

router = APIRouter()


class PredictionPayload(BaseModel):
    crop: str = Field(..., examples=["tomato"])
    disease: str = Field(..., examples=["early_blight"])
    confidence: float = Field(..., ge=0.0, le=1.0)
    region: Optional[str] = None
    device_id: Optional[str] = None
    created_at: Optional[datetime] = None


class ReportResponse(BaseModel):
    id: int
    crop: str
    disease: str
    confidence: float
    region: Optional[str] = None
    device_id: Optional[str] = None
    created_at: datetime
    message: str


@router.post("/reports", response_model=ReportResponse, status_code=201)
@router.post("/report", response_model=ReportResponse, status_code=201)
def receive_report(
    data: PredictionPayload,
    db: Session = Depends(get_db),
) -> ReportResponse:
    report = DiseaseReport(
        crop=data.crop,
        disease=data.disease,
        confidence=data.confidence,
        region=data.region,
        device_id=data.device_id,
    )
    if data.created_at is not None:
        report.created_at = data.created_at

    db.add(report)
    db.commit()
    db.refresh(report)

    return ReportResponse(
        id=report.id,
        crop=report.crop,
        disease=report.disease,
        confidence=report.confidence,
        region=report.region,
        device_id=report.device_id,
        created_at=report.created_at,
        message="Report saved successfully",
    )


@router.get("/reports", response_model=list[ReportResponse])
def get_reports(
    limit: int = 50,
    crop: Optional[str] = None,
    db: Session = Depends(get_db),
) -> list[ReportResponse]:
    query = db.query(DiseaseReport)
    if crop:
        query = query.filter(DiseaseReport.crop == crop)

    reports = query.order_by(DiseaseReport.created_at.desc()).limit(limit).all()
    return [
        ReportResponse(
            id=report.id,
            crop=report.crop,
            disease=report.disease,
            confidence=report.confidence,
            region=report.region,
            device_id=report.device_id,
            created_at=report.created_at,
            message="",
        )
        for report in reports
    ]
