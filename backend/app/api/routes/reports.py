"""리포트 라우트 (FR10) — **manager 전용**."""
from __future__ import annotations

from datetime import date
from enum import StrEnum

from fastapi import APIRouter

from app.api.deps import CurrentManager, SessionDep
from app.core.timeframe import Period, period_bounds
from app.crud import report as report_crud
from app.schemas.report import ReceivingReport

router = APIRouter(prefix="/reports", tags=["reports"])


class ReportPeriod(StrEnum):
    """일간은 막대가 하나뿐이라 그래프의 의미가 없어 제외한다."""

    week = "week"
    month = "month"


@router.get("/receiving", response_model=ReceivingReport)
def receiving_report(
    session: SessionDep,
    _: CurrentManager,
    period: ReportPeriod = ReportPeriod.week,
    anchor: date | None = None,
) -> ReceivingReport:
    start, end = period_bounds(Period(period.value), anchor)
    return ReceivingReport(**report_crud.receiving_report(session, start=start, end=end))
