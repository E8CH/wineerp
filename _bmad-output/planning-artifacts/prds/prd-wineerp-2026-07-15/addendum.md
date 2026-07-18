# Addendum — wineerp PRD

PRD 본문엔 넣지 않는 "구현 방법(technical-how)" 상세. 아키텍처 단계 입력용.

## LLM (라벨 모델명 추론, FR-6)

- **제공자:** Gemini / OpenAI (클라우드 비전-언어 모델). 둘 다 사용 가능하도록 API 키가 프로젝트 **env 파일**에 준비됨.
  - > 키 값은 이 문서에 기록하지 않는다. env 파일은 비밀정보 → 버전관리 제외(.gitignore) 필수.
- **함의:**
  - **데이터 전송:** 라벨 사진이 외부(Google/OpenAI)로 전송됨 → 고객사 데이터/개인정보 정책 확인 필요(OQ-6). 온프렘/경량 모델 대안은 정책 불가 시 검토.
  - **지연·비용:** 호출당 지연·과금 발생. 현장 흐름을 끊지 않도록 목표 응답 3~5초(§10 NFR), 모델·프롬프트·이미지 압축으로 최적화.
  - **제공자 선택:** 정확도/비용/지연을 POC에서 비교(둘 다 키 보유) 후 확정. 폴백·재시도 전략 아키텍처에서 설계.
- **불변식:** 추론 결과는 항상 직원이 수정·확정(SM-C2). 저신뢰/실패 시 수동 입력 폴백(FR-6).

## 후보 기술 스택 (브리프 addendum 참조)

- 상세 스택(Flutter·FastAPI·PostgreSQL·Railway 등)은 브리프 addendum `_bmad-output/planning-artifacts/briefs/brief-wineerp-2026-07-15/addendum.md`에 있음. 확정은 아키텍처 단계.
