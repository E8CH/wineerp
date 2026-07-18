# features (feature-first)

각 기능은 자기 디렉터리에 화면·프로바이더·위젯을 둔다. FR→디렉터리 매핑:

- `auth/`          — 로그인·역할 분기 (FR1,2 / Story 1.3,1.4)
- `scan/`          — 스캔→카드→후보 (FR3,4,5 / Story 2.2,2.4,2.5)
- `receiving/`     — 수량·완료·수정·메모 (FR7,8,12 / Story 2.6,4.x)
- `registration/`  — 신규등록 LLM 추론 (FR6 / Story 3.2)
- `initial_setup/` — 초기 세팅 연속 등록 (FR13 / Story 3.3)
- `report/`        — 일/주/월·그래프·엑셀 (FR9,10,11 / Story 4.1,5.x)
