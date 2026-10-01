# JBL 브랜드 디자인 시스템

> 출처: https://www.jbl.com/personalize.html (JBL 공식 사이트, Salesforce Commerce Cloud 기반) 의 실제 CSS/HTML을 분석하여 추출한 디자인 토큰과 스타일 가이드입니다.

## 1. 브랜드 톤앤매너

- **키워드**: 강렬함(Bold), 산업적(Industrial), 사운드/에너지 중심, 스트리트/퍼포먼스 감성
- 순정 오렌지(시그니처 컬러) + 블랙/화이트의 고대비 조합으로 강한 임팩트를 주는 스타일
- 헤드라인은 대문자(uppercase) + 넓은 자간(letter-spacing)으로 포스터/광고 같은 인상을 줌
- 버튼과 UI 요소는 각진(sharp corner, radius 0) 형태가 기본 — 라운드보다 직선적이고 견고한 느낌 강조
- 제품 개인화(Personalize) 페이지처럼 "나만의 커스터마이징"을 중심에 둔 인터랙티브하고 다이내믹한 경험 지향

## 2. 컬러 팔레트

### Primary
| 이름 | HEX | 용도 |
|---|---|---|
| JBL Orange (Primary) | `#fa4616` | 시그니처 브랜드 컬러, Primary 버튼, 링크 강조, CTA |
| Orange Deep | `#d73204` | hover/active 상태, 보조 강조 |
| Black | `#000000` | 텍스트, 배경(다크 섹션), 아이콘 |
| White | `#ffffff` | 배경, 다크 섹션 위 텍스트 |

### Neutral (Grayscale)
| 이름 | HEX |
|---|---|
| Gray 1 (진한 회색) | `#545454` |
| Gray 2 (중간 회색) | `#838383` |
| Gray 3 (연한 회색) | `#c2c2c2` |
| Dark Cream (톤 배경) | `#dedac8` |

### Semantic / Status
| 이름 | HEX | 용도 |
|---|---|---|
| Success Green | `#148346` / `#3e8626` | 성공/완료 상태 |
| Error/Danger Red | `#a63232` / `#df2d00` | 오류, 경고 강조 |
| Warning Yellow | `#ffc107` | 주의 알림 |
| Info Blue | `#17a2b8` | 정보성 메시지 |

**사용 원칙**: 배경은 대부분 화이트 또는 블랙(고대비)이며, 오렌지는 "액션을 유도하는 요소"(버튼, 링크, 강조 배지)에만 제한적으로 사용해 시그니처 컬러의 임팩트를 유지합니다.

## 3. 타이포그래피

### 폰트 패밀리
| 역할 | 폰트 스택 | 비고 |
|---|---|---|
| 헤드라인 (Headline) | `roc-grotesk`, "Roc Grotesk", system-ui, sans-serif | 굵고 각진 산업용 산세리프. 확장 버전(`roc-grotesk-condensed`, `-compressed`, `-wide`, `-extrawide`)도 배너/타이틀에 사용 |
| 본문 (Body) | `abc-diatype`, "ABC Diatype", roc-grotesk, system-ui, sans-serif | 가독성 높은 모던 산세리프 |
| 버튼 (Button) | `abc-diatype`(본문과 동일), font-weight **bold** | |
| 아이콘 폰트 | `JBL`, "Material Symbols Outlined" | 커스텀 아이콘 폰트 + Material Symbols 병행 |

### 스타일 규칙
- **헤드라인 텍스트 변환**: `uppercase` (대문자) 고정
- **헤드라인 굵기**: `font-weight: 500` (미디엄, 얇은 듯하지만 큰 사이즈로 존재감 확보)
- **자간(letter-spacing)**: 헤드라인/라벨에 `0.1em ~ 0.2em`의 넓은 트래킹을 적용해 포스터형 타이포 연출. 본문은 `-1px ~ 0`의 타이트한 자간도 혼용
- **버튼 텍스트**: 굵게(bold), 대문자 처리가 일반적

## 4. 버튼 & CTA 스타일

- **모서리(radius)**: `0` — 완전한 직각. JBL은 라운드 버튼을 거의 쓰지 않고 각진 형태를 브랜드 아이덴티티로 사용
- **Primary 버튼**: 배경 `#fa4616`(오렌지), 텍스트 `#ffffff`, border `#fa4616`
- **Outline 버튼**: 배경 투명, 텍스트/보더 `#fa4616`
- **Secondary/Dark 버튼**: 블랙 배경 + 화이트 텍스트 조합도 다수 사용
- hover 시 색상이 더 짙은 톤(`#d73204`)으로 전환되는 패턴

```css
.btn-primary { color:#fff; background-color:#fa4616; border-color:#fa4616; border-radius:0; }
.btn-outline-primary { color:#fa4616; border-color:#fa4616; border-radius:0; }
```

## 5. 스페이싱 시스템

4px 기반의 스케일(토큰명은 T-shirt 사이즈):

| 토큰 | 값 |
|---|---|
| `--spacing-2xs` | 4px |
| `--spacing-3xs` | 2px |
| `--spacing-l` | 32px |
| `--spacing-2xl` | 48px |
| `--spacing-3xl` | 56px |
| `--spacing-4xl` | 64px |
| `--spacing-5xl` | 72px |
| `--spacing-6xl` | 80px |
| `--spacing-7xl` | 88px |
| `--spacing-8xl` | 96px |

각 값에는 대응하는 negative 버전(예: `--spacing-l-negative: -32px`)이 존재하여 오버랩 레이아웃(이미지가 섹션 경계를 넘어가는 연출)에 사용됩니다.

## 6. 브레이크포인트

| 구분 | 기준 |
|---|---|
| Mobile | ~767px 이하 |
| Tablet | ~1023px 이하 |
| Small Desktop | ~1199px 이하 |
| Desktop | ~1200px ~ 1399px |
| Large Desktop | 1400px 이상 |

## 7. 레이아웃 & 인터랙션 패턴 (Personalize 페이지 기준)

- **개인화 컨피규레이터(Configurator)**: 제품 이미지 + 컬러/각인(Engraving) 옵션을 실시간으로 반영하는 모달/전체화면 UI (`modal-pdp-personalization__configurator`)
- 제품을 크게 보여주는 히어로형 비주얼 + 옵션 스와치(컬러칩) 선택 UI 조합
- 다이내믹 렌더링: 사용자가 색상/텍스트를 선택하면 제품 미리보기가 즉시 갱신되는 실시간 프리뷰 방식
- 모바일 대응을 위한 반응형 모달(`d-none d-sm-block` 등 Bootstrap 유틸리티 클래스 사용 — Bootstrap 기반 커스터마이징)

## 8. 아이콘 & 이미지 스타일

- 커스텀 아이콘 폰트(`JBL`) + `Material Symbols Outlined`를 함께 사용 — 라인/아웃라인 스타일의 미니멀한 UI 아이콘
- 제품 이미지는 고해상도 스튜디오 컷 위주, 블랙/화이트 배경에 제품이 부각되는 구도
- 컬러 스와치는 원형 또는 사각 칩 형태로 실제 제품 컬러를 반영

## 9. 요약 — 디자인 토큰 Quick Reference

```
Primary Color:      #fa4616
Primary Hover:      #d73204
Text/Ink:           #000000
Background:         #ffffff
Gray Scale:         #545454, #838383, #c2c2c2
Accent (warm bg):   #dedac8
Headline Font:      roc-grotesk (uppercase, weight 500, wide tracking)
Body Font:          abc-diatype
Button Font Weight: bold
Button Radius:      0 (sharp corners)
Spacing Base:       4px increments (2px ~ 96px scale)
```
