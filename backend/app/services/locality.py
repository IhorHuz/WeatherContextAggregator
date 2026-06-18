import httpx
from app.models.schemas import LocalityInfo
from app.services.exceptions import UpstreamHTTPError, UpstreamParseError, UpstreamTimeoutError

NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"

# Nominatim address keys that represent interesting nearby features
_FEATURE_KEYS = ["suburb", "city_district", "district", "neighbourhood", "quarter", "county"]

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
    "residential": "residential area",
}


def _classify_locality(raw_type: str) -> str:
    return _LOCALITY_TYPE_MAP.get(raw_type.lower(), raw_type or "area")


# Keys checked in order — broader settlement type wins (city beats suburb within it)
_TYPE_PRIORITY = ["city", "town", "village", "hamlet", "suburb", "neighbourhood", "borough", "municipality"]


def _locality_type_from_address(address: dict, addresstype_fallback: str) -> str:
    """Use the address object to infer settlement type (more reliable than addresstype)."""
    for key in _TYPE_PRIORITY:
        if key in address:
            return _classify_locality(key)
    return _classify_locality(addresstype_fallback)


def _region_from_address(address: dict) -> str:
    """Return the best available administrative region name."""
    for key in ("state", "region", "state_district", "county"):
        value = address.get(key, "").strip()
        if value:
            return value
    return ""


def _extract_features(address: dict, city: str) -> list[str]:
    features = []
    for key in _FEATURE_KEYS:
        value = address.get(key, "").strip()
        if value and value != city:
            features.append(value)
            if len(features) >= 5:
                break
    return features


async def get_locality(lat: float, lon: float, city: str) -> LocalityInfo:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                NOMINATIM_URL,
                params={"format": "json", "lat": lat, "lon": lon, "accept-language": "en"},
                # Nominatim usage policy requires an identifying User-Agent
                headers={"User-Agent": "WeatherContextAggregator/1.0"},
            )
            resp.raise_for_status()
    except httpx.TimeoutException as exc:
        raise UpstreamTimeoutError("nominatim") from exc
    except httpx.HTTPStatusError as exc:
        raise UpstreamHTTPError("nominatim", exc.response.status_code) from exc

    try:
        data = resp.json()
        address = data.get("address", {})
        return LocalityInfo(
            city=city,
            locality_type=_locality_type_from_address(address, data.get("addresstype", "")),
            country=address.get("country", ""),
            region=_region_from_address(address),
            nearby_features=_extract_features(address, city),
        )
    except (KeyError, ValueError) as exc:
        raise UpstreamParseError("nominatim") from exc
