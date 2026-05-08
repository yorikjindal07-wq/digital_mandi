import os

import httpx
from fastapi import APIRouter, HTTPException, Query

router = APIRouter()

OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY", "")
OPENWEATHER_WEATHER_URL = "https://api.openweathermap.org/data/2.5/weather"
OPENWEATHER_FORECAST_URL = "https://api.openweathermap.org/data/2.5/forecast"


def _require_weather_key() -> str:
    if not OPENWEATHER_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="OPENWEATHER_API_KEY not configured on backend.",
        )
    return OPENWEATHER_API_KEY


async def _forward(url: str, params: dict[str, str]) -> dict:
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.get(url, params=params)
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError:
            detail = "Weather provider error"
            try:
                payload = response.json()
                if isinstance(payload, dict) and isinstance(payload.get("message"), str):
                    detail = payload["message"]
            except ValueError:
                pass
            raise HTTPException(status_code=response.status_code, detail=detail)
        return response.json()


@router.get("/weather/by-city")
async def weather_by_city(
    city: str = Query(..., min_length=1, max_length=120),
    language: str = Query("en", min_length=2, max_length=10),
) -> dict:
    api_key = _require_weather_key()
    return await _forward(
        OPENWEATHER_WEATHER_URL,
        {
            "q": city.strip(),
            "appid": api_key,
            "units": "metric",
            "lang": language,
        },
    )


@router.get("/weather/by-coordinates")
async def weather_by_coordinates(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    language: str = Query("en", min_length=2, max_length=10),
) -> dict:
    api_key = _require_weather_key()
    return await _forward(
        OPENWEATHER_WEATHER_URL,
        {
            "lat": str(latitude),
            "lon": str(longitude),
            "appid": api_key,
            "units": "metric",
            "lang": language,
        },
    )


@router.get("/weather/forecast")
async def weather_forecast(
    city: str = Query(..., min_length=1, max_length=120),
    language: str = Query("en", min_length=2, max_length=10),
) -> dict:
    api_key = _require_weather_key()
    return await _forward(
        OPENWEATHER_FORECAST_URL,
        {
            "q": city.strip(),
            "appid": api_key,
            "units": "metric",
            "lang": language,
        },
    )
