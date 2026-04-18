# ─────────────────────────────────────────────
# backend/app/api/db/models.py
# SQLAlchemy ORM models
# ─────────────────────────────────────────────

from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean
from sqlalchemy.sql import func
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class DiseaseReport(Base):
    __tablename__ = 'disease_reports'

    id         = Column(Integer, primary_key=True, index=True)
    crop       = Column(String,  nullable=False, index=True)
    disease    = Column(String,  nullable=False, index=True)
    confidence = Column(Float,   nullable=False)
    region     = Column(String,  nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    device_id  = Column(String,  nullable=True)

    def __repr__(self):
        return f"<DiseaseReport {self.crop}/{self.disease} {self.confidence:.2f}>"


class OutbreakAlert(Base):
    __tablename__ = 'outbreak_alerts'

    id         = Column(Integer, primary_key=True, index=True)
    disease    = Column(String,  nullable=False)
    region     = Column(String,  nullable=False)
    count      = Column(Integer, default=0)
    severity   = Column(String,  default='low')   # low, medium, high
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    is_active  = Column(Boolean, default=True)


# ─────────────────────────────────────────────
# backend/app/api/report.py
# ─────────────────────────────────────────────

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from typing import List, Optional
import logging

logger = logging.getLogger(__name__)
router = APIRouter()


class PredictionPayload(BaseModel):
    crop:       str   = Field(..., example='tomato')
    disease:    str   = Field(..., example='early_blight')
    confidence: float = Field(..., ge=0.0, le=1.0)
    region:     Optional[str] = None
    device_id:  Optional[str] = None


class ReportResponse(BaseModel):
    id:         int
    crop:       str
    disease:    str
    confidence: float
    message:    str


@router.post('/report', response_model=ReportResponse)
def receive_report(
    data: PredictionPayload,
    db:   Session = Depends(lambda: next(get_db())),
):
    """
    Receive a disease detection report from the mobile app.
    Saves to database and checks for outbreak patterns.
    """
    from app.api.db.models  import DiseaseReport
    from app.api.db.database import get_db

    report = DiseaseReport(
        crop       = data.crop,
        disease    = data.disease,
        confidence = data.confidence,
        region     = data.region,
        device_id  = data.device_id,
    )
    db.add(report)
    db.commit()
    db.refresh(report)

    logger.info(f"Report saved: {report.crop}/{report.disease} ({report.confidence:.2f})")

    return ReportResponse(
        id         = report.id,
        crop       = report.crop,
        disease    = report.disease,
        confidence = report.confidence,
        message    = 'Report saved successfully',
    )


@router.get('/reports', response_model=List[ReportResponse])
def get_reports(
    limit:  int     = 50,
    crop:   Optional[str] = None,
    db:     Session = Depends(lambda: next(get_db())),
):
    """Fetch recent disease reports (for dashboard/analytics)."""
    from app.api.db.models  import DiseaseReport
    from app.api.db.database import get_db

    query = db.query(DiseaseReport)
    if crop:
        query = query.filter(DiseaseReport.crop == crop)
    reports = query.order_by(DiseaseReport.created_at.desc()).limit(limit).all()

    return [
        ReportResponse(
            id=r.id, crop=r.crop, disease=r.disease,
            confidence=r.confidence, message='',
        )
        for r in reports
    ]


# ─────────────────────────────────────────────
# backend/app/api/weather.py
# ─────────────────────────────────────────────

weather_router = APIRouter()


@weather_router.get('/weather/{region}')
def get_weather(region: str, season: str = 'kharif'):
    """
    Return weather data for a region and season.
    In production, connect to IMD / OpenWeatherMap API here.
    """
    weather_db = {
        'Punjab': {
            'summer': {'temp_min': 35, 'temp_max': 44, 'rain_mm': 20, 'humidity': 40},
            'kharif': {'temp_min': 28, 'temp_max': 35, 'rain_mm': 90, 'humidity': 75},
            'winter': {'temp_min':  4, 'temp_max': 18, 'rain_mm': 35, 'humidity': 60},
        },
    }

    region_data = weather_db.get(region)
    if not region_data:
        raise HTTPException(status_code=404, detail=f'Region {region} not found')

    season_data = region_data.get(season)
    if not season_data:
        raise HTTPException(status_code=404, detail=f'Season {season} not found')

    return {
        'region': region,
        'season': season,
        'data':   season_data,
        'source': 'historical_average',
    }


# ─────────────────────────────────────────────
# backend/app/api/sync.py
# ─────────────────────────────────────────────

sync_router = APIRouter()


@sync_router.get('/sync/status')
def sync_status():
    return {'status': 'ok', 'server_time': str(__import__('datetime').datetime.now())}


@sync_router.post('/sync/bulk')
def sync_bulk(reports: List[PredictionPayload]):
    """Accept bulk upload of locally queued reports."""
    saved = 0
    for r in reports:
        # In production, call receive_report for each
        saved += 1
    return {'message': f'Synced {saved} reports', 'saved': saved}


# ─────────────────────────────────────────────
# backend/app/api/federated.py
# ─────────────────────────────────────────────

federated_router = APIRouter()


@federated_router.get('/federated/check-update')
def check_model_update():
    """Check if a new model version is available for download."""
    return {
        'update_available': False,
        'current_version':  '1.0.0',
        'model_url':        None,
    }


@federated_router.post('/federated/gradients')
def receive_gradients(data: dict):
    """
    Receive anonymised gradient updates for federated learning.
    In production, aggregate with FedAvg and update global model.
    """
    return {'status': 'gradient received', 'message': 'Thank you for contributing'}