from datetime import datetime, timedelta, timezone


def utc_iso(dt: datetime | None) -> str | None:
    """Serialize a naive UTC datetime as ISO-8601 with a Z suffix."""
    if dt is None:
        return None
    aware = dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)
    return aware.isoformat().replace("+00:00", "Z")


def utc_epoch_ms(dt: datetime | None) -> int | None:
    if dt is None:
        return None
    aware = dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)
    return int(aware.timestamp() * 1000)


def local_wall_clock(dt: datetime, timezone_offset_minutes: int | None) -> datetime:
    """Convert a stored UTC timestamp to the recorder's local wall clock."""
    if dt is None:
        return datetime.utcnow()
    aware = dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)
    if timezone_offset_minutes is None:
        return aware.replace(tzinfo=None)
    return (aware + timedelta(minutes=timezone_offset_minutes)).replace(tzinfo=None)
