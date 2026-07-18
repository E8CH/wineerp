"""Ports — 외부 벤더를 격리하는 인터페이스(Protocol). 구현은 app/adapters.

리서치(2026-07-17): 외부 와인 API는 조용히 죽는다 → 벤더를 Port 뒤에 두고 교체 가능하게 한다.
실제 시그니처는 해당 스토리에서 확정:
  - LabelInferencePort  : Story 3.1 (Gemini/OpenAI, 유료 티어)
  - WineCatalogPort     : Story 2.1/3.x (LWIN 로컬 1차 + api4ai 슬롯)
  - StoragePort         : Story 2.3 (Cloudflare R2, EXIF 제거)
"""
from __future__ import annotations

from typing import Protocol


class LabelInferencePort(Protocol):
    """라벨 이미지 → 모델명 초안 추론. 페이로드는 라벨 이미지만(PII·매입가 배제)."""

    def infer_model_name(self, image_key: str) -> InferenceResult: ...


class WineCatalogPort(Protocol):
    """LWIN 등 카탈로그 조회. lwin7/lwin11을 내부 표준키로 반환."""

    def search(self, query: str) -> list[dict]: ...


class StoragePort(Protocol):
    """오브젝트 스토리지(R2). 업로드 시 EXIF 제거, DB에는 key만 저장."""

    def put_object(self, data: bytes, key: str, content_type: str) -> str: ...


class InferenceResult:
    """추론 결과 — 실패/저신뢰를 도메인 값으로 반환해 UI가 수동 폴백(FR-6)으로 분기하게 한다."""

    def __init__(self, model_name: str | None, confidence: float, failed: bool = False) -> None:
        self.model_name = model_name
        self.confidence = confidence
        self.failed = failed
