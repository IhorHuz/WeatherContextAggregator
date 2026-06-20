import pytest
import httpx
import respx
from app.services.locality import _classify_locality, _extract_features, get_locality
from app.services.exceptions import UpstreamHTTPError, UpstreamTimeoutError

NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"

SAMPLE_RESPONSE = {
    "addresstype": "city",
    "address": {
        "city": "Bratislava",
        "state": "Bratislava Region",
        "country": "Slovakia",
        "suburb": "Staré Mesto",
        "county": "Okres Bratislava I",
    },
}

SAMPLE_ADDRESS = SAMPLE_RESPONSE["address"]


class TestClassifyLocality:
    def test_city(self):
        assert _classify_locality("city") == "city"

    def test_town(self):
        assert _classify_locality("town") == "town"

    def test_village(self):
        assert _classify_locality("village") == "village"

    def test_case_insensitive(self):
        assert _classify_locality("CITY") == "city"

    def test_unknown_type_passthrough(self):
        assert _classify_locality("metropolis") == "metropolis"

    def test_empty_returns_area(self):
        assert _classify_locality("") == "area"


class TestExtractFeatures:
    def test_extracts_suburb(self):
        features = _extract_features(SAMPLE_ADDRESS, "Bratislava")
        assert "Staré Mesto" in features

    def test_skips_city_name_duplicate(self):
        address = {"suburb": "Bratislava", "county": "Okres Bratislava I"}
        features = _extract_features(address, "Bratislava")
        assert "Bratislava" not in features

    def test_respects_limit_of_5(self):
        address = {k: f"Feature {i}" for i, k in enumerate(
            ["suburb", "city_district", "district", "neighbourhood", "quarter", "county"]
        )}
        assert len(_extract_features(address, "TestCity")) <= 5

    def test_empty_input(self):
        assert _extract_features({}, "Bratislava") == []


class TestGetLocality:
    @respx.mock
    async def test_happy_path(self):
        respx.get(NOMINATIM_URL).mock(return_value=httpx.Response(200, json=SAMPLE_RESPONSE))
        result = await get_locality(48.1486, 17.1077, "Bratislava")
        assert result.locality_type == "city"
        assert result.country == "Slovakia"
        assert result.region == "Bratislava Region"
        assert "Staré Mesto" in result.nearby_features

    @respx.mock
    async def test_timeout_raises_upstream_error(self):
        def _timeout(r):
            raise httpx.ConnectTimeout("timed out", request=r)
        respx.get(NOMINATIM_URL).mock(side_effect=_timeout)
        with pytest.raises(UpstreamTimeoutError):
            await get_locality(48.1486, 17.1077, "Bratislava")

    @respx.mock
    async def test_http_error_raises_upstream_error(self):
        respx.get(NOMINATIM_URL).mock(return_value=httpx.Response(429))
        with pytest.raises(UpstreamHTTPError) as exc_info:
            await get_locality(48.1486, 17.1077, "Bratislava")
        assert exc_info.value.status_code == 429
