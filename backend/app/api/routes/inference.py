"""라벨 추론 라우트 (FR6 지원, AR4).

⚠️ 이미지 바이트를 **여기서** 읽어 어댑터에 넘긴다. 어댑터에 key를 넘기면 어댑터가
스토리지·DB에 닿을 수 있게 되고, 그러면 LLM 페이로드에 무엇이 들어가는지 타입으로
보장할 수 없다(AR9).
"""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, LabelInferenceDep, StorageDep
from app.schemas.inference import InferenceRead, LabelInferenceRequest

router = APIRouter(prefix="/inference", tags=["inference"])


@router.post("/label", response_model=InferenceRead)
def infer_label(
    payload: LabelInferenceRequest,
    storage: StorageDep,
    inference: LabelInferenceDep,
    _: CurrentUser,
) -> InferenceRead:
    try:
        image = storage.get_object(payload.image_key)
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="이미지를 찾을 수 없습니다.",
        ) from exc

    # 실패·저신뢰는 예외가 아니라 값으로 온다 — UI가 수동 입력으로 분기한다(FR6).
    result = inference.infer(image, payload.content_type)
    return InferenceRead(
        model_name=result.model_name,
        confidence=result.confidence,
        failed=result.failed,
        low_confidence=result.is_low_confidence,
        needs_manual_input=result.needs_manual_input,
        reason=result.reason,
    )
