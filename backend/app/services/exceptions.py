class UpstreamError(Exception):
    def __init__(self, service: str, detail: str = ""):
        self.service = service
        self.detail = detail
        super().__init__(detail or f"error from {service}")


class UpstreamTimeoutError(UpstreamError):
    pass


class UpstreamHTTPError(UpstreamError):
    def __init__(self, service: str, status_code: int):
        self.status_code = status_code
        super().__init__(service, f"HTTP {status_code} from {service}")


class UpstreamParseError(UpstreamError):
    pass
