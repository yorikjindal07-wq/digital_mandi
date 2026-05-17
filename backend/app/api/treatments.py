from fastapi import APIRouter, HTTPException, Query

from app.services.treatment_api_service import load_treatments

router = APIRouter()


@router.get("/treatments")
def list_treatments(
    disease: str | None = Query(default=None, min_length=1, max_length=120),
) -> dict:
    treatments = load_treatments()
    if disease is None:
        return treatments

    treatment = treatments.get(disease)
    if not isinstance(treatment, dict):
        raise HTTPException(status_code=404, detail="Treatment not found")

    return {disease: treatment}


@router.get("/treatments/{disease_key}")
def get_treatment(disease_key: str) -> dict:
    treatments = load_treatments()
    treatment = treatments.get(disease_key)
    if not isinstance(treatment, dict):
        raise HTTPException(status_code=404, detail="Treatment not found")
    return treatment
