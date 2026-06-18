from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class WeatherInfo(BaseModel):
    temperature_c: float = Field(description="Current air temperature in Celsius")
    humidity_pct: int = Field(description="Relative humidity as a percentage (0–100)")
    wind_speed_kmh: float = Field(description="Wind speed at 10 m height in km/h")
    pollen_level: str = Field(description="Aggregated pollen risk: low, moderate, high, or unknown")

    model_config = {"json_schema_extra": {"example": {
        "temperature_c": 18.5, "humidity_pct": 65, "wind_speed_kmh": 12.4, "pollen_level": "low"
    }}}


class AstronomyInfo(BaseModel):
    sunrise: str = Field(description="Local sunrise time in HH:MM format")
    sunset: str = Field(description="Local sunset time in HH:MM format")
    solar_noon: str = Field(description="Local solar noon time in HH:MM format")
    day_length: str = Field(description="Total daylight duration")

    model_config = {"json_schema_extra": {"example": {
        "sunrise": "06:12", "sunset": "21:55", "solar_noon": "14:03", "day_length": "15h 43m"
    }}}


class LocalityInfo(BaseModel):
    city: str = Field(description="Resolved city or locality name")
    locality_type: str = Field(description="Settlement type: city, town, village, hamlet, suburb, etc.")
    country: str = Field(description="Country name")
    region: str = Field(description="Principal subdivision (state or region)")
    nearby_features: list[str] = Field(description="Named geographic features near the location")

    model_config = {"json_schema_extra": {"example": {
        "city": "Bratislava", "locality_type": "city", "country": "Slovakia",
        "region": "Bratislava Region", "nearby_features": ["Danube", "Little Carpathians"]
    }}}


class ContextRequest(BaseModel):
    lat: float = Field(description="WGS84 latitude")
    lon: float = Field(description="WGS84 longitude")
    city: str = Field(description="City name resolved by the iOS client")
    timezone: str = Field(default="UTC", description="IANA timezone string sent by the client")

    model_config = {"json_schema_extra": {"example": {
        "lat": 48.1486, "lon": 17.1077, "city": "Bratislava", "timezone": "Europe/Bratislava"
    }}}


class ContextResponse(BaseModel):
    lat: float = Field(description="Request latitude")
    lon: float = Field(description="Request longitude")
    timezone: str = Field(description="IANA timezone auto-detected from coordinates by Open-Meteo")
    weather: WeatherInfo
    astronomy: AstronomyInfo
    locality: LocalityInfo
    cached_at: Optional[datetime] = Field(default=None, description="UTC timestamp when data was last fetched from upstream APIs")
