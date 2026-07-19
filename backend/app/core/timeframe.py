"""기간 경계 계산 (FR9, FR10).

⚠️ `received_at`은 UTC로 저장되지만 "일간/주간/월간"은 **한국 달력**이다.
UTC로 경계를 자르면 오전 9시(KST) 이전 입고가 전부 전날로 분류된다 — 창고 작업이
오전에 몰리므로 매일 상당수가 어긋나고, 화면은 정상으로 보인다.

리포트(Epic 5)도 같은 경계를 써야 하므로 여기 한 곳에만 둔다.
"""
from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from enum import StrEnum
from zoneinfo import ZoneInfo

from app.core.config import settings


class Period(StrEnum):
    day = "day"
    week = "week"
    month = "month"


def period_bounds(
    period: Period, anchor: date | None = None, tz_name: str | None = None
) -> tuple[datetime, datetime]:
    """[start, end) UTC 경계를 돌려준다. 경계는 로컬 시간대(기본 KST) 달력 기준."""
    tz = ZoneInfo(tz_name or settings.TIMEZONE)
    today = anchor or datetime.now(tz).date()

    if period == Period.day:
        start_local = datetime.combine(today, datetime.min.time(), tzinfo=tz)
        end_local = start_local + timedelta(days=1)
    elif period == Period.week:
        # ISO 주 — 월요일 시작.
        monday = today - timedelta(days=today.weekday())
        start_local = datetime.combine(monday, datetime.min.time(), tzinfo=tz)
        end_local = start_local + timedelta(days=7)
    else:
        first = today.replace(day=1)
        start_local = datetime.combine(first, datetime.min.time(), tzinfo=tz)
        next_month = (first + timedelta(days=32)).replace(day=1)
        end_local = datetime.combine(next_month, datetime.min.time(), tzinfo=tz)

    return start_local.astimezone(UTC), end_local.astimezone(UTC)
