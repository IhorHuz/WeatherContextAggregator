import os
import httpx
from app.models.schemas import LocalityInfo
from app.services.exceptions import UpstreamHTTPError, UpstreamParseError, UpstreamTimeoutError

BIGDATACLOUD_URL = "https://api.bigdatacloud.net/data/reverse-geocode"

_SKIP_DESCRIPTIONS = {"continent", "country", "ISO 3166-1 Alpha-2", "ISO 3166-1 Alpha-3"}

_LOCALITY_TYPE_MAP = {
    "city": "city",
    "town": "town",
    "village": "village",
    "hamlet": "hamlet",
    "suburb": "suburb",
    "neighbourhood": "neighbourhood",
    "borough": "borough",
    "municipality": "municipality",
    "administrative": "area",
}


def _classify_locality(raw_type: str) -> str:
    return _LOCALITY_TYPE_MAP.get(raw_type.lower(), raw_type or "area")


def _extract_features(locality_info: dict) -> list[str]:
    features = []
    for entry in locality_info.get("informative", []):
        if entry.get("description") in _SKIP_DESCRIPTIONS:
            continue
        name = entry.get("name", "").strip()
        if name:
            features.append(name)
            if len(features) >= 5:
                break
    return features


async def get_locality(lat: float, lon: float, city: str) -> LocalityInfo:
    params: dict = {"latitude": lat, "longitude": lon, "localityLanguage": "en"}
    api_key = os.getenv("BIGDATACLOUD_API_KEY", "")
    if api_key:
        params["key"] = api_key

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(BIGDATACLOUD_URL, params=params)
            resp.raise_for_status()
    except httpx.TimeoutException as exc:
        raise UpstreamTimeoutError("bigdatacloud") from exc
    except httpx.HTTPStatusError as exc:
        raise UpstreamHTTPError("bigdatacloud", exc.response.status_code) from exc

    try:
        data = resp.json()
        return LocalityInfo(
            city=city,
            locality_type=_classify_locality(data.get("localityType", "")),
            country=data.get("countryName", ""),
            region=data.get("principalSubdivision", ""),
            nearby_features=_extract_features(data.get("localityInfo", {})),
        )
    except (KeyError, ValueError) as exc:
        raise UpstreamParseError("bigdatacloud") from exc
