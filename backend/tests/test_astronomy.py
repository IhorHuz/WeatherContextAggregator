import pytest
import httpx
import respx
from app.services.astronomy import get_astronomy
from app.services.exceptions import UpstreamHTTPError, UpstreamParseError, UpstreamTimeoutError

SUNRISESUNSET_URL = "https://api.sunrisesunset.io/json"

ASTRONOMY_JSON = {
    "results": {
        "sunrise": "6:12:00 AM",
        "sunset": "9:55:00 PM",
        "solar_noon": "2:03:00 PM",
        "day_length": "15:43:09",
    }
}


class TestGetAstronomy:
    @respx.mock
    async def test_happy_path(self):
        respx.get(SUNRISESUNSET_URL).mock(return_value=httpx.Response(200, json=ASTRONOMY_JSON))
        result = await get_astronomy(48.1486, 17.1077, "Europe/Bratislava")
        assert result.sunrise == "06:12"
        assert result.sunset == "21:55"
        assert result.solar_noon == "14:03"
        assert result.day_length == "15h 43m"

    @respx.mock
    async def test_timeout_raises_upstream_timeout(self):
        def _timeout(r):
            raise httpx.ConnectTimeout("timed out", request=r)
        respx.get(SUNRISESUNSET_URL).mock(side_effect=_timeout)
        with pytest.raises(UpstreamTimeoutError):
            await get_astronomy(48.1486, 17.1077, "Europe/Bratislava")

    @respx.mock
    async def test_http_error_raises_upstream_http_error(self):
        respx.get(SUNRISESUNSET_URL).mock(return_value=httpx.Response(503))
        with pytest.raises(UpstreamHTTPError) as exc_info:
            await get_astronomy(48.1486, 17.1077, "Europe/Bratislava")
        assert exc_info.value.status_code == 503

    @respx.mock
    async def test_connection_error_raises_upstream_timeout(self):
        def _connect_error(r):
            raise httpx.ConnectError("connection refused", request=r)
        respx.get(SUNRISESUNSET_URL).mock(side_effect=_connect_error)
        with pytest.raises(UpstreamTimeoutError):
            await get_astronomy(48.1486, 17.1077, "Europe/Bratislava")

    @respx.mock
    async def test_parse_error_raises_upstream_parse_error(self):
        respx.get(SUNRISESUNSET_URL).mock(return_value=httpx.Response(200, json={"status": "OK"}))
        with pytest.raises(UpstreamParseError):
            await get_astronomy(48.1486, 17.1077, "Europe/Bratislava")
