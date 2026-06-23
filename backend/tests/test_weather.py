import pytest
import httpx
import respx
from app.services.weather import get_weather
from app.services.exceptions import UpstreamHTTPError, UpstreamParseError, UpstreamTimeoutError

FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
AIR_URL = "https://air-quality-api.open-meteo.com/v1/air-quality"

FORECAST_JSON = {
    "timezone": "Europe/Bratislava",
    "current": {"temperature_2m": 18.5, "relative_humidity_2m": 65, "wind_speed_10m": 12.4},
}
AIR_JSON = {
    "current": {"birch_pollen": 5.0, "grass_pollen": 3.0, "mugwort_pollen": 1.0, "ragweed_pollen": 0.5}
}


class TestGetWeather:
    @respx.mock
    async def test_happy_path(self):
        respx.get(FORECAST_URL).mock(return_value=httpx.Response(200, json=FORECAST_JSON))
        respx.get(AIR_URL).mock(return_value=httpx.Response(200, json=AIR_JSON))
        weather, timezone = await get_weather(48.1486, 17.1077)
        assert weather.temperature_c == 18.5
        assert weather.humidity_pct == 65
        assert weather.wind_speed_kmh == 12.4
        assert weather.pollen_level == "low"
        assert timezone == "Europe/Bratislava"

    @respx.mock
    async def test_timeout_raises_upstream_timeout(self):
        def _timeout(r):
            raise httpx.ConnectTimeout("timed out", request=r)
        respx.get(FORECAST_URL).mock(side_effect=_timeout)
        respx.get(AIR_URL).mock(return_value=httpx.Response(200, json=AIR_JSON))
        with pytest.raises(UpstreamTimeoutError):
            await get_weather(48.1486, 17.1077)

    @respx.mock
    async def test_http_error_raises_upstream_http_error(self):
        respx.get(FORECAST_URL).mock(return_value=httpx.Response(503))
        respx.get(AIR_URL).mock(return_value=httpx.Response(200, json=AIR_JSON))
        with pytest.raises(UpstreamHTTPError) as exc_info:
            await get_weather(48.1486, 17.1077)
        assert exc_info.value.status_code == 503

    @respx.mock
    async def test_connection_error_raises_upstream_timeout(self):
        def _connect_error(r):
            raise httpx.ConnectError("connection refused", request=r)
        respx.get(FORECAST_URL).mock(side_effect=_connect_error)
        respx.get(AIR_URL).mock(return_value=httpx.Response(200, json=AIR_JSON))
        with pytest.raises(UpstreamTimeoutError):
            await get_weather(48.1486, 17.1077)

    @respx.mock
    async def test_parse_error_raises_upstream_parse_error(self):
        respx.get(FORECAST_URL).mock(return_value=httpx.Response(200, json={"timezone": "UTC"}))
        respx.get(AIR_URL).mock(return_value=httpx.Response(200, json=AIR_JSON))
        with pytest.raises(UpstreamParseError):
            await get_weather(48.1486, 17.1077)
