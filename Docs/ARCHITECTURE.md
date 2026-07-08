# HWANGTODO 아키텍처 결정 기록 (2026-07)

제품 명세는 [REQUIREMENTS.md](REQUIREMENTS.md), 운영 규칙은 [../CLAUDE.md](../CLAUDE.md).

## 결정 요약

| # | 결정 | 선택 | 이유 |
|---|------|------|------|
| D1 | 배포 타깃 | **iOS 26.0** | "2026.07 최첨단" 요구. Liquid Glass 네이티브, `Tab` 빌더, `tabViewBottomAccessory`, 인터랙티브 위젯/Live Activity, ControlWidget을 가드 없이 사용. 개인용 앱이라 설치 기반 제약 없음. |
| D2 | 영속성 | **SwiftData + App Group 컨테이너** | 기존 JSON 스토어의 치명 결함 3개(프로세스 간 트랜잭션 없음, 마이그레이션 없음, 디코드 실패 시 조용한 전체 소실)를 SQLite/WAL이 해결. 위젯·인텐트·앱이 같은 스토어를 공유. 구 JSON은 `LegacyJSONImporter`가 1회 이관(원본은 `.imported`로 보존, 실패 시 재시도). |
| D3 | 동시성 | **Swift 6 모드 + Approachable Concurrency + MainActor 기본 격리** | 앱 타깃·패키지는 MainActor 기본, 위젯 익스텐션은 nonisolated 기본(타임라인 프로바이더가 메인 밖에서 돎). 순수 데이터 타입은 명시적 `nonisolated`. `ObservableObject` 전면 제거, `@Observable`만 사용. |
| D4 | 모듈 구조 | **로컬 SPM 패키지 `HWANGTODOKit`** (Core/Design) + 앱/위젯 타깃 | 디렉터리 글롭 컴파일이 만든 `Enums 2.swift` 류 사고 차단, 같은 소스 이중 컴파일 제거, 패키지 테스트로 빠른 검증. `project.yml`이 프로젝트의 단일 진실. |
| D5 | 디자인 | **절제된 Liquid Glass** | 시스템 컴포넌트가 글래스를 담당, 커스텀 `.glassEffect()`는 히어로 요소에만. 색은 코드 정의 적응형(라이트/다크), 타이포는 Dynamic Type 토큰만. 문자열 카탈로그 대신 한국어 리터럴 + `Terminology` 상수 + 금지어 테스트(단일 언어 서비스라 로컬라이제이션 레이어는 과설계로 판단). |
| D6 | 테스트/개발환경 | **Swift Testing**(패키지) + SwiftLint/SwiftFormat/Makefile/GitHub Actions | 커버 대상: ThoughtSplitter(§12 표준 예시), Routine 통계, DeepLink 왕복, Repository 뮤테이션, 레거시 임포트 안전성, 용어 금지어 스캔. |

## 데이터 흐름

```
시스템 표면(위젯 버튼·제어센터·Siri·단축어)          앱 UI
        │  AppIntent (위젯 프로세스)                    │
        ▼                                              ▼
  SharedStore.context  ◀── App Group SQLite ──▶  TodoRepository(@Observable)
        │                                              │
        └── WidgetCenter.reloadAllTimelines() ◀────────┘
                     (포그라운드 복귀 시 repository.reload())
```

- 위젯 프로세스의 쓰기는 앱이 `scenePhase == .active`에서 `reload()`로 수용.
- Live Activity 갱신은 앱 프로세스의 `FocusSessionManager`가 소유한 `Activity` 핸들로 수행.
- 딥링크는 `DeepLink`(생성) ↔ `AppRouter`(해석)로 왕복 대칭; 호스트 문자열은 동결.

## 고정(동결) 항목

App Group `group.com.hwangtodo.shared` · URL 스킴 `hwangtodo` · enum rawValue
(`Quadrant`/`TaskStatus`/`CaptureSource`) · `WidgetKind` 문자열 · 딥링크 호스트.
바꾸면 배치된 위젯/예약된 알림/저장 데이터가 깨진다.

## 알려진 iOS 제약 (정직하게 표기)

- 잠금화면 위젯 안 텍스트 입력 불가 → 확인·진입·Live Activity 중심 (§6.1).
- Siri 문구는 반드시 `.applicationName` 포함 — 맨몸 "할 일 추가"는 불가 (§6.3).
- 제어센터에 전체 편집기 불가 → 컨트롤은 빠른 기록 진입만 (§6.5).
- 액션 버튼/제어센터/Siri 설정 여부는 앱이 감지 불가 → 설정 체크리스트에서 "확인 필요"로 정직 표기 (§13).
- Dynamic Island는 Pro 계열 실기기 전용; Live Activity 상호작용 버튼은 위젯 프로세스에서 실행됨.
