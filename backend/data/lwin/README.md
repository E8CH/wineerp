# LWIN 시드 데이터 (내부 표준키)

Story 2.1에서 이 디렉터리에 LWIN CSV를 배치해 로딩한다.

- 출처: Liv-ex LWIN (Creative Commons BY, 무료). LWIN-7(와인) / LWIN-11(+빈티지) / LWIN-18(+사이즈).
- 용도: `WineProduct.lwin7` / `WineVintage.lwin11`을 내부 표준키로 두어 카탈로그 벤더(api4ai·InVintory) 교체 시에도 안정적으로 매핑.
- ⚠️ LWIN에는 바코드/GTIN이 없다. 한국 커버리지는 미검증(bake-off로 실측 필요).

CSV는 용량이 커 저장소에 커밋하지 않을 수 있음(다운로드 스크립트로 대체 가능) — Story 2.1에서 결정.
