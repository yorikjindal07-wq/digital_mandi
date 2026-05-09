import asyncio
import os
import time
from typing import Any

import httpx
from fastapi import APIRouter, HTTPException, Query

router = APIRouter()

OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY", "")
OPENWEATHER_WEATHER_URL = "https://api.openweathermap.org/data/2.5/weather"
OPENWEATHER_FORECAST_URL = "https://api.openweathermap.org/data/2.5/forecast"
OPENWEATHER_TIMEOUT = httpx.Timeout(connect=3.0, read=8.0, write=8.0, pool=3.0)
CURRENT_WEATHER_CACHE_TTL_SECONDS = 600
FORECAST_CACHE_TTL_SECONDS = 900

_weather_cache: dict[tuple[str, tuple[tuple[str, str], ...]], tuple[float, dict[str, Any]]] = {}


def _require_weather_key() -> str:
    if not OPENWEATHER_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="OPENWEATHER_API_KEY not configured on backend.",
        )
    return OPENWEATHER_API_KEY


def _cache_key(url: str, params: dict[str, str]) -> tuple[str, tuple[tuple[str, str], ...]]:
    return url, tuple(sorted((key, value) for key, value in params.items()))


def _read_cache(url: str, params: dict[str, str]) -> dict[str, Any] | None:
    key = _cache_key(url, params)
    cached = _weather_cache.get(key)
    if cached is None:
        return None

    expires_at, payload = cached
    if expires_at <= time.monotonic():
        _weather_cache.pop(key, None)
        return None

    return payload


def _write_cache(url: str, params: dict[str, str], payload: dict[str, Any], ttl_seconds: int) -> None:
    _weather_cache[_cache_key(url, params)] = (
        time.monotonic() + ttl_seconds,
        payload,
    )


async def _forward(url: str, params: dict[str, str], *, ttl_seconds: int) -> dict[str, Any]:
    cached = _read_cache(url, params)
    if cached is not None:
        return cached

    try:
        async with httpx.AsyncClient(timeout=OPENWEATHER_TIMEOUT) as client:
            response = await client.get(url, params=params)
    except httpx.TimeoutException as exc:
        raise HTTPException(status_code=504, detail="Weather provider timed out.") from exc
    except httpx.RequestError as exc:
        raise HTTPException(status_code=502, detail="Weather provider is unavailable.") from exc

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

    payload = response.json()
    if not isinstance(payload, dict):
        raise HTTPException(status_code=502, detail="Weather provider returned an invalid response.")

    _write_cache(url, params, payload, ttl_seconds)
    return payload


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
        ttl_seconds=CURRENT_WEATHER_CACHE_TTL_SECONDS,
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
        ttl_seconds=CURRENT_WEATHER_CACHE_TTL_SECONDS,
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
        ttl_seconds=FORECAST_CACHE_TTL_SECONDS,
    )


@router.get("/weather/summary")
async def weather_summary(
    city: str = Query(..., min_length=1, max_length=120),
    language: str = Query("en", min_length=2, max_length=10),
) -> dict[str, Any]:
    api_key = _require_weather_key()
    normalized_city = city.strip()

    current_params = {
        "q": normalized_city,
        "appid": api_key,
        "units": "metric",
        "lang": language,
    }
    forecast_params = {
        "q": normalized_city,
        "appid": api_key,
        "units": "metric",
        "lang": language,
    }

    current, forecast = await asyncio.gather(
        _forward(
            OPENWEATHER_WEATHER_URL,
            current_params,
            ttl_seconds=CURRENT_WEATHER_CACHE_TTL_SECONDS,
        ),
        _forward(
            OPENWEATHER_FORECAST_URL,
            forecast_params,
            ttl_seconds=FORECAST_CACHE_TTL_SECONDS,
        ),
    )

    return {
        "current": current,
        "forecast": forecast,
    }
