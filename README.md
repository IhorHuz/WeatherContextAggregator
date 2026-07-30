_Hello!_ This repository holds the work done during the Individual Study Plan course at the Lodz University of Technology.

The project is a mobile app that looks at your GPS location and tells you three things: current weather(including temperature, wind speed, humidity and pollen count), sunrise and sunset times, and your locality - whether you are in a city, a village, or somewhere in nature. It does this by talking to three free APIs that require no API keys - Open-Meteo, SunriseSunset.io, and Nominatim - and stitching their answers together in under a second.

The backend runs on a single EC2 instance in Frankfurt, provisioned with Terraform. A Jenkins pipeline tests, builds, and redeploys the Docker container automatically on every push to `main`.

---

## What is inside

| Directory                   | Contents                                         |
| --------------------------- | ------------------------------------------------ |
| `WeatherContextAggregator/` | iOS app (Swift / SwiftUI)                        |
| `backend/`                  | FastAPI server (Python)                          |
| `infrastructure/`           | Terraform files, Jenkins pipeline, setup scripts |
| `docs/`                     | Research, market analysis, final report          |

## Stack

| Layer     | Technology                                    |
| --------- | --------------------------------------------- |
| Mobile    | Swift / SwiftUI                               |
| Backend   | Python / FastAPI                              |
| Infra     | Terraform, AWS, Docker                        |
| CI/CD     | Jenkins                                       |
| Weather   | Open-Meteo                                    |
| Astronomy | SunriseSunset.io                              |
| Geocoding | BigDataCloud (client), Nominatim/OSM (server) |

## Tests and CI

The backend has 6 test files covering each service, error handling, and the full endpoint. Run them with:

```bash
cd backend && pip install -r requirements.txt && python -m pytest tests/ -v
```

The Jenkins pipeline definition is at `backend/Jenkinsfile`. The same tests also run in GitHub Actions on every push.

## Trying the iOS app

Open `WeatherContextAggregator/WeatherContextAggregator.xcodeproj` in Xcode.

**Simulator:** Select an iPhone destination and press Run. The app will use your simulated location — in the Simulator menu bar, go to Features → Location and pick a preset or enter custom coordinates. By default it points to the live server.

**Physical device:** You will need a free Apple Developer account. In Signing & Capabilities, select your team and use a unique bundle identifier. Connect your iPhone, select it as the destination, and run. Location permissions will prompt on first launch.

To run against a local backend instead, change the URL in `AppConfig.swift`.
