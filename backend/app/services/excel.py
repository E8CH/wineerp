"""엑셀 리포트 생성 (FR11).

⚠️ CSV가 아니라 진짜 `.xlsx`인 이유: CSV를 한국어 Windows Excel에서 열면 cp949/UTF-8
불일치로 **와인명이 깨진다**(한국 로케일에서 가장 흔한 실패). BOM을 붙여도 구분자·따옴표
처리가 환경마다 다르다. `.xlsx`는 인코딩 모호성이 없다.

⚠️ 일시는 **KST로 변환해 쓴다**. Excel 셀에는 시간대 개념이 없어 UTC를 그대로 넣으면
오전 입고가 전날로 보인다 — 4.1과 같은 함정이다.
"""
from __future__ import annotations

import io
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill

from app.core.config import settings

HEADERS = ["입고일시", "모델명", "생산자", "빈티지", "수량", "담당자", "구분", "메모"]
_SOURCE_LABEL = {"receiving": "입고", "initial_setup": "초기 세팅"}


def build_receiving_workbook(rows: list[tuple]) -> bytes:
    """`crud.receiving.list_records` 결과를 엑셀 바이트로."""
    tz = ZoneInfo(settings.TIMEZONE)
    wb = Workbook()
    ws = wb.active
    ws.title = "입고 내역"

    ws.append(HEADERS)
    header_fill = PatternFill("solid", fgColor="123E7C")  # 네이비
    for cell in ws[1]:
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center")

    for rec, vintage, product, user in rows:
        received = rec.received_at
        if received.tzinfo is None:  # SQLite는 오프셋을 저장하지 않는다
            received = received.replace(tzinfo=UTC)
        ws.append(
            [
                received.astimezone(tz).strftime("%Y-%m-%d %H:%M"),
                product.model_name,
                product.producer,
                # NV는 빈칸이 아니라 "NV"로 쓴다 — 빈칸이면 "빠뜨린 값"으로 읽힌다.
                vintage.vintage if vintage.vintage is not None else "NV",
                rec.quantity,
                user.email,
                _SOURCE_LABEL.get(str(rec.source), str(rec.source)),
                rec.memo or "",
            ]
        )

    widths = [18, 28, 22, 10, 8, 24, 12, 40]
    for idx, width in enumerate(widths, start=1):
        ws.column_dimensions[ws.cell(row=1, column=idx).column_letter].width = width
    ws.freeze_panes = "A2"

    buffer = io.BytesIO()
    wb.save(buffer)
    return buffer.getvalue()


def filename_for(start: datetime, end: datetime) -> str:
    """ASCII 파일명만 쓴다.

    한글 파일명은 `Content-Disposition`에서 RFC 5987 인코딩이 필요하고 클라이언트마다
    처리가 갈린다. 파일 내용은 한국어이므로 파일명까지 한글일 이유가 없다.
    """
    tz = ZoneInfo(settings.TIMEZONE)
    s = start.astimezone(tz).date().isoformat()
    # end는 배타적이다. 그대로 쓰면 7/13~7/19 주간 파일이 이름으로 7/20을 주장한다.
    e = (end.astimezone(tz) - timedelta(seconds=1)).date().isoformat()
    return f"wineerp-receiving-{s}_{e}.xlsx"
