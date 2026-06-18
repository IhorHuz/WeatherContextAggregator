import asyncio
import httpx
from app.models.schemas import WeatherInfo
from app.services.exceptions import UpstreamHTTPError, UpstreamParseError, UpstreamTimeoutError

FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
AIR_QUALITY_URL = "https://air-quality-api.open-meteo.com/v1/air-quality"


def _pollen_level(air_current: dict) -> str:
    keys = ["birch_pollen", "grass_pollen", "mugwort_pollen", "ragweed_pollen"]
    values = [air_current[k] for k in keys if air_current.get(k) is not None]
    if not values:
        return "unknown"
    peak = max(values)
    if peak < 10:
        return "low"
    elif peak < 50:
        return "moderate"
    return "high"


async def get_weather(lat: float, lon: float) -> tuple[WeatherInfo, str]:
    """Returns (WeatherInfo, IANA timezone string detected from coordinates)."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            forecast_resp, air_resp = await asyncio.gather(
                client.get(FORECAST_URL, params={
                    "latitude": lat,
                    "longitude": lon,
                    "current": "temperature_2m,relative_humidity_2m,wind_speed_10m",
                    "wind_speed_unit": "kmh",
                    "timezone": "auto",
                }),
                client.get(AIR_QUALITY_URL, params={
                    "latitude": lat,
                    "longitude": lon,
                    "current": "birch_pollen,grass_pollen,mugwort_pollen,ragweed_pollen",
                }),
            )
            forecast_resp.raise_for_status()
            air_resp.raise_for_status()
    except httpx.TimeoutException as exc:
        raise UpstreamTimeoutError("open_meteo") from exc
    except httpx.HTTPStatusError as exc:
        raise UpstreamHTTPError("open_meteo", exc.response.status_code) from exc

    try:
        forecast_json = forecast_resp.json()
        current = forecast_json["current"]
        air_current = air_resp.json().get("current", {})
        # Open-Meteo detects the correct IANA timezone from the coordinates when
        # timezone=auto is used. We use this to ensure astronomy times are always
        # expressed in the location's local time, not the device's system timezone.
        detected_timezone = forecast_json.get("timezone", "UTC")
    except (KeyError, ValueError) as exc:
        raise UpstreamParseError("open_meteo") from exc

    return WeatherInfo(
        temperature_c=current["temperature_2m"],
        humidity_pct=current["relative_humidity_2m"],
        wind_speed_kmh=current["wind_speed_10m"],
        pollen_level=_pollen_level(air_current),
    ), detected_timezone
