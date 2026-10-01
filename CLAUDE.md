# Circle Design Harness

## 목적

제품 디자이너가 매번 제공하는 PRD·화면 설계서·레퍼런스를 바탕으로 화면 디자인 초안을 만들고, 선택되지 않은 디자인 exploration 결과물과 최종 결과물 선정 이유를 정리한 문서, 디자인 토큰 및 컴포넌트를 산출한다.

## 필수 컨텍스트

실행 전에 아래 파일이 모두 있는지 확인한다. 하나라도 없으면 실행을 멈추고 누락 파일을 보고한다.

- `docs/prd.md`
- `docs/design.md`
- `docs/story-service.md`
- `docs/story-work.md`

`docs/story-service.md`는 서비스 기준이고 `docs/story-work.md`는 실제 작업 순서 기준이다. 두 기준을 섞지 않는다.

## 단계와 담당 에이전트

각 에이전트는 자신의 편집 폴더만 수정한다. 실행별 산출물은 `runs/<run-id>/`에 보관한다.

1. **레퍼런스 수집·분석 — 디자인 리서처**
   - 입력: PRD, 화면 설계서, 레퍼런스
   - 출력: `01-reference-analysis.md`
   - 레퍼런스 반영 포인트를 정리한다.
   - 게이트: 반영할 포인트를 선정한다.
   - 작업 폴더: `runs/<run-id>/agents/design-researcher/`

2. **키스크린 제작 — 컨셉 디자이너**
   - 입력: 1단계 분석 결과와 화면 설계서
   - 출력: Figma Design 파일과 `02-key-screens/` 내 440×440 SVG export, `figma-state.json`
   - 먼저 현재 세션의 MCP 도구 목록에서 `create_new_file`, `use_figma`, `get_metadata`, `get_screenshot` 작업을 확인하고 실제 도구 ID 전체를 `figma-capabilities.json`에 기록한다. 목록을 추측하거나 수동으로 채우지 않는다.
   - Figma MCP의 `create_new_file`로 Design 파일을 만들고 `use_figma`로 440×440 원형 UI 키스크린 2~3개를 그린다. `get_metadata`로 프레임 ID·크기·텍스트를 읽어 상태 증거를 저장한다.
   - `figma-capabilities.json`에는 현재 실행의 `run_id`와 MCP 도구 목록을 저장한다. `figma-state.json`에는 `verified_via: figma_mcp`, 같은 `run_id`, `capabilities_sha256`, `file_url`, `file_key`, 그리고 프레임별 `name`, `node_id`, `width`, `height`, `visible_text`를 기록한다. `metrics.yaml`의 `figma_frame_name`과 프레임 이름을 일치시킨다.
   - Figma MCP가 없으면 로컬 SVG로 대체하지 말고 2단계를 막는다. Plugin Management에서 Figma가 설치·활성화로 확인됐는데도 쓰기 도구가 누락되면 재연결을 반복 요청하지 않는다. 확인된 활성 상태, 현재 노출된 읽기 도구, 누락된 쓰기 도구를 구분해 보고한다.
   - 판정기는 실제 Figma MCP 프레임명·노드 ID·크기·표시 텍스트를 SVG export와 대조한다.
   - 이 단계에는 별도 게이트를 두지 않는다.
   - 작업 폴더: `runs/<run-id>/agents/concept-designer/`

3. **내부 컨셉 협의·확정 — 컨셉 디자이너**
   - 입력: 키스크린
   - 출력: `03-concept-decision.md`
   - 키스크린을 바탕으로 컨셉 방향을 정리한다.
   - 게이트: 내부 컨셉 확정.
   - 컨셉 피드백이 있으면 1단계로 돌아간다.
   - 사람 승인은 이 단계가 끝난 뒤 한 번 받는다. 승인 전에는 4단계로 진행하지 않는다.

4. **화면 설계·디자인 옵션 — 컨셉 디자이너 + UX Writer**
   - 입력: 승인된 컨셉
   - 컨셉 디자이너 출력: `04-screen-spec-and-explorations.md`
   - UX Writer 출력: `04-ux-copy.md`, `04-ux-copy.yaml`
   - 컨셉 디자이너는 화면 설계를 구체화하고 디자인 옵션 2~3개를 만든다.
   - UX Writer는 승인된 컨셉과 키스크린에 맞는 화면 문구를 작성하고 글자 수를 기록한다. 원형 화면 텍스트 제한과 한 화면당 정보 하나 규칙을 따른다.
   - 키워드 검사는 실제 화면에 표시되는 Figma/SVG 텍스트와 `04-ux-copy.yaml`의 `primary_text`·`supporting_text`에만 적용한다. 근거·설명·규칙 문구는 검사 대상에서 제외한다.
   - YAML에는 화면별 `screen`, `primary_information_count`, `primary_text`, `supporting_text`, `list_items` 필드를 둔다.
   - 두 역할은 각자의 전용 폴더만 편집한다. 최종 디자이너는 5단계 입력으로 화면 문구를 사용한다.
   - 이 단계에는 별도 게이트를 두지 않는다.

5. **최종 디자인·컴포넌트 — 최종 디자이너**
   - 입력: 디자인 옵션과 `04-ux-copy.md`
   - 출력: `05-final-design/`
   - 화면 디자인 초안, 디자인 토큰 및 컴포넌트를 만들고 반복 개선한다.
   - 선택되지 않은 exploration 결과물과 최종 결과물 선정 이유를 기록한다.
   - 최종 디자인 피드백은 4단계로 돌려보낸다.
   - 작업 폴더: `runs/<run-id>/agents/final-designer/`
   - `05-final-design/review.yaml`에는 `design_tokens`, `components`, `screen_design` 파일 경로, 각 미선택 exploration의 `reason`, `final_selection_reason`을 기록한다.

## 기계 판정

`harness-rules.yaml`을 규칙의 단일 기준(SSOT)으로 사용한다.

- 원형 화면의 핵심 정보 수는 정확히 1개여야 한다.
- 원형 화면의 문자열은 최대 20자, 목록 항목은 0개여야 한다.
- 핵심 조작별 제스처 단계는 최대 1단계, 완료 시간은 최대 3초여야 한다.
- 찾기 모드와 귀가 체크는 `location_audience: party_members_only`, `user_opt_in: true`, `auto_disable_on_party_end: true`를 모두 명시해야 한다.
- 각 단계 완료 후 판정자가 규칙을 검사한다. 실패하면 해당 산출물을 만든 에이전트에게 돌려보낸다.
- 판정자는 읽기 전용이며 산출물을 직접 수정하지 않는다.
- 판정 스크립트: `ruby scripts/judge.rb runs/<run-id> --through <단계번호>`
- 3단계 사람 승인을 받은 직후 `ruby scripts/record_approval.rb runs/<run-id> --confirm-human-approval`을 실행해 승인 시점의 컨텍스트와 1~3단계 입력 SHA-256을 저장한다. 이 명령은 명시적 사용자 승인 뒤에만 실행한다.

## 실행 및 재개

- 자연어 트리거: “하네스 실행”
- `orchestrator-rules.yaml`에 따라 단계를 순서대로 실행하고, 매 단계 뒤 판정한다.
- `runs/<run-id>/`에 실행 산출물을 보존한다.
- 재개 시 기존 산출물을 다시 판정한다. 3단계 이후 재개는 `03-approval.json`의 승인 상태와 입력 해시가 현재 파일과 일치해야 한다. 입력이 바뀌었으면 승인을 무효화하고 3단계에서 다시 확인받는다.

## 검증과 리뷰

`validation-review.yaml`에 따라 단계별 산출물·필수 필드·키스크린 크기를 확인한다. 키스크린은 정확히 440×440이어야 한다. 화면 정보 수, 글자 수, 목록 항목 수, 조작 단계·시간, 위치 정보 조건은 JSON 또는 YAML 구조화 메타데이터에 기록된 값을 판정한다. 구현된 판정 스크립트는 Ruby 표준 YAML/XML 라이브러리만 사용한다.

완료 리포트에는 단계별 산출물 경로, 통과·실패 규칙, 사람 승인 기록, 미선택 exploration, 최종 선정 이유를 포함한다.

판정기 회귀 테스트는 `ruby scripts/test_harness.rb`로 실행한다. 이 테스트는 성공 사례와 규칙 위반·승인 누락·승인 후 입력 변경·Figma 상태 불일치 사례를 재현한다. 현재 환경에서 Figma MCP 생성/조회 도구가 없으면 2단계를 중단하고 사용자에게 연결을 요청한다.
