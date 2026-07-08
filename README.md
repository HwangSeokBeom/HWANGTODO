# HWANGTODO

**앱을 열지 않고 기록하세요. 떠오른 일은 빠르게 남기고, 정리는 나중에 해도 괜찮아요.**

HWANGTODO는 "앱 안에서 TODO를 쓰는 앱"이 아니라, **잠금화면·액션 버튼·Siri·
단축어·제어센터·위젯·알림 같은 iOS 시스템 표면에서 1초 안에 기록하는 캡처 앱**이다.
앱 본체는 들어온 할 일을 정리(매트릭스)·일정화(캘린더)·루틴화하고 메모/채팅으로
생각을 잇는 **관리 HQ** 역할을 한다.

제품 명세: [Docs/REQUIREMENTS.md](Docs/REQUIREMENTS.md) ·
아키텍처 결정 기록: [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) ·
검증 매트릭스: [VERIFICATION.md](VERIFICATION.md)

## 구성

| 탭 | 역할 |
|----|------|
| 기록 | 빠른 기록 홈 — 시스템 표면에서 들어온 할 일 + 오늘 요약 + 정리 전/완료한 일 |
| 정리 | 아이젠하워 매트릭스 (지금 할 일/계획할 일/맡길 일/줄일 일) — 정리 레이어 |
| 일정 | Apple Calendar 연동 오늘 계획 (지난 할 일/오늘/다가오는) |
| 루틴 | 요일 반복 + 완료율 + 스트릭 |
| 설정 | 시스템 표면 라이브 체크리스트 (사용 가능/설정 필요/확인 필요) |

시스템 표면: 홈 위젯 3종(S/M/L, 인터랙티브 완료 버튼) · 잠금화면 위젯 3종 ·
제어센터/액션 버튼 컨트롤 · Siri App Shortcuts(한국어 문구) · 단축어 인텐트 ·
알림 액션(완료/나중에/오늘로/집중/열기) · Live Matrix(Live Activity + Dynamic Island).

## 빌드 & 실행

요구: Xcode 26+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
선택: `brew install swiftlint swiftformat` → `make lint` / `make format`.

```bash
make gen     # project.yml → HWANGTODO.xcodeproj (소스 추가/삭제 후 필수)
make build   # 시뮬레이터 빌드
make test    # Swift Testing 유닛 테스트
make run     # 부팅된 시뮬레이터에 설치+실행
```

`project.yml`이 프로젝트의 단일 진실이다 — pbxproj를 직접 수정하지 말 것.
서명이 Manual인 이유는 project.yml 주석 참고 (App Group 엔타이틀먼트 보존).

## 아키텍처 (요약)

- **iOS 26.0+ / Swift 6 언어 모드 / MainActor 기본 격리** (위젯 타깃은 nonisolated 기본)
- **SwiftData + App Group SQLite** — 앱·위젯·인텐트가 같은 스토어 공유, 구 JSON은 1회 이관
- 로컬 패키지 **HWANGTODOKit**: `HWANGTODOCore`(모델·저장소·딥링크·용어·파서) + `HWANGTODODesign`(토큰·컴포넌트)
- 모든 뮤테이션은 `TodoRepository` 경유 (저장 + 위젯 타임라인 갱신 단일 지점)
- 용어는 `Terminology`/`Quadrant.title`에 고정 — 금지어(받은함·보관함)는 테스트가 막는다

## 시뮬레이터 QA 팁

```bash
# 데모 데이터와 함께 실행 (DEBUG 전용, 자동 시드 없음)
xcrun simctl launch booted com.hwangtodo.app -hwangtodo-seed-demo
# 특정 화면 바로 열기 (simctl openurl 확인 다이얼로그 우회)
xcrun simctl launch booted com.hwangtodo.app -hwangtodo-route matrix
```

실기기 전용 검증 항목(액션 버튼, Dynamic Island, Siri 음성 등)은
[VERIFICATION.md](VERIFICATION.md)의 §17 목록을 따른다.
