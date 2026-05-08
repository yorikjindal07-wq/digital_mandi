from sqlalchemy import Boolean, Column, DateTime, Float, Integer, String
from sqlalchemy.orm import declarative_base
from sqlalchemy.sql import func

Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, nullable=False, unique=True, index=True)
    password_hash = Column(String, nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    last_login_at = Column(DateTime(timezone=True), nullable=True)

    def __repr__(self) -> str:
        return f"<User {self.email}>"


class DiseaseReport(Base):
    __tablename__ = "disease_reports"

    id = Column(Integer, primary_key=True, index=True)
    crop = Column(String, nullable=False, index=True)
    disease = Column(String, nullable=False, index=True)
    confidence = Column(Float, nullable=False)
    region = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    device_id = Column(String, nullable=True)

    def __repr__(self) -> str:
        return f"<DiseaseReport {self.crop}/{self.disease} {self.confidence:.2f}>"


class OutbreakAlert(Base):
    __tablename__ = "outbreak_alerts"

    id = Column(Integer, primary_key=True, index=True)
    disease = Column(String, nullable=False)
    region = Column(String, nullable=False)
    count = Column(Integer, nullable=False, default=0)
    severity = Column(String, nullable=False, default="low")
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    is_active = Column(Boolean, nullable=False, default=True)
