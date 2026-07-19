"""Ports — 외부 벤더를 격리하는 인터페이스(Protocol). 구현은 app/adapters.

리서치(2026-07-17): 외부 와인 API는 조용히 죽는다 → 벤더를 Port 뒤에 두고 교체 가능하게 한다.
실제 시그니처는 해당 스토리에서 확정:
  - LabelInferencePort  : Story 3.1 (Gemini/OpenAI, 유료 티어)
  - WineCatalogPort     : Story 2.1/3.x (LWIN 로컬 1차 + api4ai 슬롯)
  - StoragePort         : Story 2.3 (Cloudflare R2, EXIF 제거)
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol

# 이 값 미만이면 UI가 "저신뢰" 경고를 띄우고 수동 입력을 권한다(UX-DR8, SM-C2).
# ⚠️ 이 숫자를 정확도 KPI로 삼지 말 것 — 라벨 빈티지 인식 정확도의 공개 벤치마크는
# 존재하지 않으며, 유통되는 수치는 전부 원출처 검증에 실패했다(리서치 2026-07-17).
LOW_CONFIDENCE_THRESHOLD = 0.6


@dataclass(frozen=True)
class InferenceResult:
    """추론 결과 — 실패/저신뢰를 **예외가 아니라 값으로** 반환한다.

    어댑터가 예외를 던지면 라우트마다 try/except가 번지고 하나만 빠뜨려도 500이 난다.
    값으로 두면 수동 입력 폴백(FR6) 분기가 타입에 드러난다.
    """

    model_name: str | None = None
    confidence: float = 0.0
    failed: bool = False
    reason: str | None = None

    @property
    def is_low_confidence(self) -> bool:
        return not self.failed and self.confidence < LOW_CONFIDENCE_THRESHOLD

    @property
    def needs_manual_input(self) -> bool:
        """실패했거나 모델명이 비었으면 UI는 즉시 수동 입력으로 폴백해야 한다."""
        return self.failed or not self.model_name


class LabelInferencePort(Protocol):
    """라벨 이미지 → 모델명 초안 추론.

    ⚠️ **바이트만 받는다.** `image_key`나 도메인 객체를 받지 않는 것은 편의 문제가 아니라
    구조적 보장이다 — 거래처 PII·매입가가 LLM 페이로드에 들어갈 수 있는 경로를 타입으로
    없앤다(AR9). 스토리지 접근은 라우트가 하고, 어댑터는 스토리지를 모른다.
    """

    def infer(self, image: bytes, content_type: str) -> InferenceResult: ...


class WineCatalogPort(Protocol):
    """LWIN 등 카탈로그 조회. lwin7/lwin11을 내부 표준키로 반환."""

    def search(self, query: str) -> list[dict]: ...


class StoragePort(Protocol):
    """오브젝트 스토리지(R2). 업로드 시 EXIF 제거, DB에는 key만 저장."""

    def put_object(self, data: bytes, key: str, content_type: str) -> str: ...

    def get_object(self, key: str) -> bytes: ...
