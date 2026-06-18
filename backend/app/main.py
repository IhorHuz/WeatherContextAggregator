from fastapi import FastAPI
from fastapi.responses import JSONResponse
from app.routers import context
from app.services.exceptions import UpstreamHTTPError, UpstreamParseError, UpstreamTimeoutError

app = FastAPI(
    title="Weather Context Aggregator API",
    description="Aggregates real-time weather, astronomy, and locality context for any GPS coordinate.",
    version="1.0.0",
    contact={"name": "Ihor Huz"},
)

app.include_router(context.router)


@app.get("/health", summary="Health check")
async def health():
    return {"status": "ok"}


@app.exception_handler(UpstreamTimeoutError)
async def _timeout_handler(request, exc: UpstreamTimeoutError):
    return JSONResponse(
        status_code=504,
        content={"error": "upstream_timeout", "service": exc.service, "detail": str(exc)},
    )


@app.exception_handler(UpstreamHTTPError)
async def _http_error_handler(request, exc: UpstreamHTTPError):
    return JSONResponse(
        status_code=502,
        content={"error": "upstream_http_error", "service": exc.service, "status_code": exc.status_code, "detail": str(exc)},
    )


@app.exception_handler(UpstreamParseError)
async def _parse_error_handler(request, exc: UpstreamParseError):
    return JSONResponse(
        status_code=502,
        content={"error": "upstream_parse_error", "service": exc.service, "detail": str(exc)},
    )
