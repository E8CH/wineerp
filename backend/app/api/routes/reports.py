"""리포트 라우트 (FR10) — **manager 전용**."""
from __future__ import annotations

from datetime import date
from enum import StrEnum

from fastapi import APIRouter, Response

from app.api.deps import CurrentManager, SessionDep
from app.core.timeframe import Period, period_bounds
from app.crud import receiving as receiving_crud
from app.crud import report as report_crud
from app.schemas.report import ReceivingReport
from app.services.excel import build_receiving_workbook, filename_for

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


XLSX_MEDIA_TYPE = (
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
)


@router.get("/receiving.xlsx")
def receiving_report_xlsx(
    session: SessionDep,
    _: CurrentManager,
    period: ReportPeriod = ReportPeriod.week,
    anchor: date | None = None,
) -> Response:
    """엑셀 다운로드 (FR11). 화면과 **같은 기간 경계**를 쓴다.

    리포트가 `period_bounds`를 쓰는데 여기서 따로 계산하면 화면과 파일의 숫자가
    어긋나고, 보고 문서에 첨부된 쪽이 틀린다.
    """
    start, end = period_bounds(Period(period.value), anchor)
    rows = receiving_crud.list_records(session, start=start, end=end)
    return Response(
        content=build_receiving_workbook(rows),
        media_type=XLSX_MEDIA_TYPE,
        headers={
            "Content-Disposition": f'attachment; filename="{filename_for(start, end)}"'
        },
    )
