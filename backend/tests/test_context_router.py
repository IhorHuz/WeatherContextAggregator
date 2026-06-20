import pytest
import httpx
import respx
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.services.cache import context_cache

VALID_PAYLOAD = {"lat": 48.1486, "lon": 17.1077, "city": "Bratislava", "timezone": "Europe/Bratislava"}

FORECAST_JSON = {
    "timezone": "Europe/Bratislava",
    "current": {"temperature_2m": 18.5, "relative_humidity_2m": 65, "wind_speed_10m": 12.4},
}
AIR_JSON = {
    "current": {"birch_pollen": 5.0, "grass_pollen": 3.0, "mugwort_pollen": 1.0, "ragweed_pollen": 0.5}
}
ASTRONOMY_JSON = {
    "results": {
        "sunrise": "6:12:00 AM",
        "sunset": "9:55:00 PM",
        "solar_noon": "2:03:00 PM",
        "day_length": "15:43:09",
    }
}
NOMINATIM_JSON = {
    "addresstype": "city",
    "address": {
        "city": "Bratislava",
        "state": "Bratislava Region",
        "country": "Slovakia",
        "suburb": "Staré Mesto",
    },
}


def _mock_all_upstreams():
    respx.get("https://api.open-meteo.com/v1/forecast").mock(return_value=httpx.Response(200, json=FORECAST_JSON))
    respx.get("https://air-quality-api.open-meteo.com/v1/air-quality").mock(return_value=httpx.Response(200, json=AIR_JSON))
    respx.get("https://api.sunrisesunset.io/json").mock(return_value=httpx.Response(200, json=ASTRONOMY_JSON))
    respx.get("https://nominatim.openstreetmap.org/reverse").mock(return_value=httpx.Response(200, json=NOMINATIM_JSON))


@pytest.fixture(autouse=True)
def clear_cache():
    context_cache._store.clear()
    yield
    context_cache._store.clear()


class TestContextEndpoint:
    @respx.mock
    async def test_happy_path(self):
        _mock_all_upstreams()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.post("/context", json=VALID_PAYLOAD)
        assert resp.status_code == 200
        body = resp.json()
        assert body["weather"]["temperature_c"] == 18.5
        assert body["weather"]["pollen_level"] == "low"
        assert body["astronomy"]["sunrise"] == "06:12"
        assert body["astronomy"]["day_length"] == "15h 43m"
        assert body["locality"]["locality_type"] == "city"
        assert body["locality"]["country"] == "Slovakia"
        assert body["cached_at"] is not None

    @respx.mock
    async def test_open_meteo_timeout_returns_504(self):
        def _timeout(r):
            raise httpx.ConnectTimeout("timed out", request=r)
        respx.get("https://api.open-meteo.com/v1/forecast").mock(side_effect=_timeout)
        respx.get("https://air-quality-api.open-meteo.com/v1/air-quality").mock(return_value=httpx.Response(200, json=AIR_JSON))
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.post("/context", json=VALID_PAYLOAD)
        assert resp.status_code == 504
        assert resp.json()["error"] == "upstream_timeout"
        assert resp.json()["service"] == "open_meteo"

    @respx.mock
    async def test_open_meteo_503_returns_502(self):
        respx.get("https://api.open-meteo.com/v1/forecast").mock(return_value=httpx.Response(503))
        respx.get("https://air-quality-api.open-meteo.com/v1/air-quality").mock(return_value=httpx.Response(200, json=AIR_JSON))
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp = await ac.post("/context", json=VALID_PAYLOAD)
        assert resp.status_code == 502
        assert resp.json()["error"] == "upstream_http_error"

    @respx.mock
    async def test_second_request_served_from_cache(self):
        _mock_all_upstreams()
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
            resp1 = await ac.post("/context", json=VALID_PAYLOAD)
            resp2 = await ac.post("/context", json=VALID_PAYLOAD)
        assert resp1.status_code == 200
        assert resp2.status_code == 200
        # Both responses share the same cached_at timestamp — second was served from cache
        assert resp1.json()["cached_at"] == resp2.json()["cached_at"]
