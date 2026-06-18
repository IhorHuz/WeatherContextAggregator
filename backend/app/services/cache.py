from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass
class _Entry:
    value: object
    expires_at: datetime


class TTLCache:
    def __init__(self, ttl_seconds: int = 600):
        self._store: dict[str, _Entry] = {}
        self._ttl = timedelta(seconds=ttl_seconds)

    def get(self, key: str):
        entry = self._store.get(key)
        if entry and datetime.utcnow() < entry.expires_at:
            return entry.value
        return None

    def set(self, key: str, value: object) -> None:
        self._store[key] = _Entry(value=value, expires_at=datetime.utcnow() + self._ttl)


context_cache = TTLCache(ttl_seconds=600)
