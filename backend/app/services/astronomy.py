import httpx
from datetime import datetime
from app.models.schemas import AstronomyInfo
from app.services.exceptions import UpstreamHTTPError, UpstreamParseError, UpstreamTimeoutError

SUNRISESUNSET_URL = "https://api.sunrisesunset.io/json"


def _fmt_time(raw: str) -> str:
    """'6:00:33 AM' → '06:00'"""
    return datetime.strptime(raw, "%I:%M:%S %p").strftime("%H:%M")


def _fmt_day_length(raw: str) -> str:
    """'15:43:09' → '15h 43m'"""
    h, m, _ = raw.split(":")
    return f"{int(h)}h {int(m)}m"


async def get_astronomy(lat: float, lon: float, timezone: str = "UTC") -> AstronomyInfo:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(SUNRISESUNSET_URL, params={
                "lat": lat,
                "lng": lon,
                "date": "today",
                "timezone": timezone,
            })
            resp.raise_for_status()
    except httpx.TimeoutException as exc:
        raise UpstreamTimeoutError("sunrisesunset") from exc
    except httpx.HTTPStatusError as exc:
        raise UpstreamHTTPError("sunrisesunset", exc.response.status_code) from exc

    try:
        data = resp.json()["results"]
        return AstronomyInfo(
            sunrise=_fmt_time(data["sunrise"]),
            sunset=_fmt_time(data["sunset"]),
            solar_noon=_fmt_time(data["solar_noon"]),
            day_length=_fmt_day_length(data["day_length"]),
        )
    except (KeyError, ValueError) as exc:
        raise UpstreamParseError("sunrisesunset") from exc
