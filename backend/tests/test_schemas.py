from app.services.weather import _pollen_level
from app.services.astronomy import _fmt_time, _fmt_day_length


class TestPollenLevel:
    def test_low_below_10(self):
        assert _pollen_level({"birch_pollen": 9.9}) == "low"

    def test_moderate_at_10(self):
        assert _pollen_level({"birch_pollen": 10.0}) == "moderate"

    def test_moderate_below_50(self):
        assert _pollen_level({"grass_pollen": 49.9}) == "moderate"

    def test_high_at_50(self):
        assert _pollen_level({"grass_pollen": 50.0}) == "high"

    def test_high_above_50(self):
        assert _pollen_level({"ragweed_pollen": 100.0}) == "high"

    def test_unknown_when_no_data(self):
        assert _pollen_level({}) == "unknown"

    def test_uses_peak_value(self):
        assert _pollen_level({"birch_pollen": 5.0, "grass_pollen": 60.0}) == "high"

    def test_ignores_none_values(self):
        assert _pollen_level({"birch_pollen": None, "grass_pollen": 5.0}) == "low"


class TestFmtTime:
    def test_am_time(self):
        assert _fmt_time("6:12:00 AM") == "06:12"

    def test_pm_time(self):
        assert _fmt_time("9:55:00 PM") == "21:55"

    def test_noon(self):
        assert _fmt_time("12:00:00 PM") == "12:00"

    def test_midnight(self):
        assert _fmt_time("12:00:00 AM") == "00:00"


class TestFmtDayLength:
    def test_standard_format(self):
        assert _fmt_day_length("15:43:09") == "15h 43m"

    def test_strips_leading_zeros(self):
        assert _fmt_day_length("08:05:00") == "8h 5m"

    def test_zero_hours(self):
        assert _fmt_day_length("0:30:00") == "0h 30m"
