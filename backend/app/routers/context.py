import asyncio
from datetime import datetime, timezone as tz
from fastapi import APIRouter
from app.models.schemas import ContextRequest, ContextResponse
from app.services.weather import get_weather
from app.services.astronomy import get_astronomy
from app.services.locality import get_locality
from app.services.cache import context_cache

router = APIRouter()


def _cache_key(lat: float, lon: float) -> str:
    return f"{round(lat, 2)},{round(lon, 2)}"


@router.post(
    "/context",
    response_model=ContextResponse,
    summary="Get contextual information for a location",
    description="Aggregates weather, astronomy, and locality data for the given GPS coordinates. "
                "Responses are cached for 10 minutes per ~1 km grid cell.",
    response_description="Aggregated context including weather, daylight window, and locality type.",
)
async def get_context(request: ContextRequest) -> ContextResponse:
    key = _cache_key(request.lat, request.lon)
    cached = context_cache.get(key)
    if cached is not None:
        return cached

    # Weather runs first to extract the timezone Open-Meteo detects from the
    # coordinates. That timezone is then passed to the astronomy call so that
    # sunrise/sunset are in the location's local time.
    weather, detected_tz = await get_weather(request.lat, request.lon)
    astronomy, locality = await asyncio.gather(
        get_astronomy(request.lat, request.lon, detected_tz),
        get_locality(request.lat, request.lon, request.city),
    )

    response = ContextResponse(
        lat=request.lat,
        lon=request.lon,
        timezone=detected_tz,
        weather=weather,
        astronomy=astronomy,
        locality=locality,
        cached_at=datetime.now(tz.utc),
    )
    context_cache.set(key, response)
    return response
