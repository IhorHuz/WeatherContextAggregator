# Weather Context Aggregator

A university project. The app reads your current location and tells you what's happening around you — weather conditions, daylight window, and whether you're in a city, a village, or somewhere near water.

## What's in here

- `WeatherContextAggregator/` — iOS app (Swift / SwiftUI)
- `backend/` — Python API (FastAPI) that fetches and combines data from external sources
- `docs/` — research documents and project write-ups

## Running it locally

**Backend**
```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload
```
API runs at `http://127.0.0.1:8000`. Interactive docs at `http://127.0.0.1:8000/docs`.

**iOS**
Open `WeatherContextAggregator/WeatherContextAggregator.xcodeproj` in Xcode and run on the simulator.

## Stack

- iOS: Swift / SwiftUI
- Backend: Python / FastAPI
- Weather: Open-Meteo
- Astronomy: SunriseSunset.io
- Reverse geocoding: BigDataCloud (client-side)
