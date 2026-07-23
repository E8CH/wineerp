"""이미지 위생 — EXIF 제거(개인정보 위생). 라벨=사물이나 EXIF/위치 메타를 설계로 소거."""
from __future__ import annotations

import io

from PIL import Image, ImageOps


def strip_exif_to_jpeg(data: bytes, max_side: int = 2000, quality: int = 85) -> bytes:
    """이미지 바이트를 받아 EXIF 없이 JPEG로 재인코딩. 과대 이미지는 축소(비용·지연 최적화).

    - RGBA/P 등은 RGB로 변환. EXIF는 재인코딩 과정에서 제거된다.
    - 손상 이미지는 PIL이 예외를 던지므로 호출측에서 처리.

    ⚠️ 회전 순서가 중요하다. 폰 카메라는 센서를 가로로 둔 채 촬영하고 세로/회전 정보를
    **EXIF Orientation 태그**에만 담는다. EXIF만 지우면(=Orientation도 사라짐) 픽셀은
    가로 그대로라 세로로 찍은 라벨이 눕는다. `exif_transpose`로 Orientation을 **픽셀에
    먼저 반영**한 뒤 재인코딩해, 어떤 뷰어(EXIF를 안 읽는 Flutter Image.memory 포함)에서도
    찍은 각도 그대로 보이게 한다.
    """
    with Image.open(io.BytesIO(data)) as img:
        img = ImageOps.exif_transpose(img)  # Orientation을 픽셀에 굽는다(그다음 EXIF 소거)
        img = img.convert("RGB")
        if max(img.size) > max_side:
            ratio = max_side / max(img.size)
            new_size = (int(img.width * ratio), int(img.height * ratio))
            img = img.resize(new_size)
        out = io.BytesIO()
        img.save(out, format="JPEG", quality=quality)  # exif 미전달 → 제거됨
        return out.getvalue()
