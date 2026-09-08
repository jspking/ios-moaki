# 모아키 (Moaki) - iOS 한글 키보드

제스처 기반 한글 입력 iOS 키보드 앱

## 프로젝트 구조

```
ios-moaki/
├── ios-moaki/              # 메인 앱 (설정 UI)
├── MoakiKeyboard/          # 키보드 익스텐션
│   ├── Engine/             # 한글 조합 로직
│   │   ├── HangulComposer.swift    # 한글 조합 상태머신
│   │   ├── GestureAnalyzer.swift   # 제스처 방향 분석
│   │   └── VowelResolver.swift     # 제스처→모음 변환
│   ├── Models/             # 데이터 모델
│   │   ├── HangulJamo.swift        # 초/중/종성 enum
│   │   ├── GestureDirection.swift  # 방향 enum
│   │   └── VowelPattern.swift      # 모음 패턴 정의
│   ├── Views/              # SwiftUI 뷰
│   │   ├── KeyboardView.swift      # 메인 키보드 + ViewModel
│   │   ├── ConsonantGridView.swift # 자음 그리드
│   │   ├── ConsonantKeyView.swift  # 개별 키
│   │   └── FunctionRowView.swift   # 하단 기능키
│   ├── Utilities/          # 유틸리티
│   │   ├── HangulConstants.swift   # 유니코드 조합 공식
│   │   └── KeyboardMetrics.swift   # 키 배치/크기
│   └── KeyboardViewController.swift # UIKit 진입점
└── MoakiKeyboardTests/     # 유닛 테스트
```

## 핵심 아키텍처

### 한글 조합 흐름

```
사용자 입력 → KeyboardViewModel → HangulComposer → ComposerAction
                    ↓                                    ↓
              제스처 분석 ←──────────────────────── 텍스트 출력
```

### HangulComposer 상태

- `empty`: 입력 없음
- `choseong(초성)`: 자음만 입력됨
- `choseongJungseong(초성, 중성)`: 자음+모음
- `complete(초성, 중성, 종성)`: 완성된 글자

### ComposerAction

- `.none`: 변화 없음
- `.update`: 조합 중인 글자 갱신 (markedText 업데이트)
- `.commit`: 글자 확정 (composedText → insertText)
- `.delete`: 삭제 동작
- `.commitAndUpdate`: 이전 글자 확정 + 새 조합 시작
- `.commitAndCommit`: 이전 글자 + 현재 글자 모두 확정

**중요**: `.commit*` 액션 발생 시 `composer.flushCommittedText()`로 확정된 텍스트를 가져와 `delegate?.insertText()`로 출력해야 함

## 모음 제스처 규칙

자음 키 위에서 드래그하여 모음 입력:

### 대각선 정규화
첫 획의 대각선은 모두 수직 방향으로 정규화됨:
- ↖, ↗ → ↑
- ↙, ↘ → ↓

기울기는 모음을 결정하지 않는다. 방향과 **획 길이**만 본다.

### 획 길이

`GestureStroke.length`는 획의 시작점에서 가장 멀리 간 지점까지의 직선
거리다. `GestureAnalyzer`가 획마다 시작점을 보관하며 갱신한다.

첫 획이 `longStrokeLength`(기본 70pt) 이상이면 긴 획으로 판정하고
`VowelPattern.longFirstStrokePatterns`를 먼저 조회한다. 전체 제스처를
소비하는 항목이 없으면 길이를 버리고 `allPatterns`로 넘어간다.

임계값은 앱의 키보드 설정에서 조절하며 `SharedKeyboardPreferences`를
통해 익스텐션에 전달된다. 기본 거리 하나가 방향 임계값 세 개를 1 : 0.5
: 1.5 비율로 함께 움직인다.

### 기본 모음

| 제스처 | 모음 |
|--------|------|
| 짧게 → | ㅏ |
| 짧게 ← | ㅓ |
| 짧게 ↑ (또는 ↖ ↗) | ㅗ |
| 짧게 ↓ (또는 ↙ ↘) | ㅜ |
| 길게 → 또는 ← | ㅡ |
| 길게 ↑ 또는 ↓ | ㅣ |

긴 획은 방향을 가리지 않는다. ㅡ는 가로축 양방향, ㅣ는 세로축 양방향
모두 같은 모음이 된다.

### Y-모음 (왕복 제스처)

| 방향 | 모음 |
|------|------|
| ↑↓↑ | ㅛ |
| ↓↑↓ | ㅠ |
| →←→ | ㅑ |
| ←→← | ㅕ |

### 복합 모음

| 방향 | 모음 |
|------|------|
| ↑→ | ㅘ |
| ↑→← | ㅙ |
| ↓← | ㅝ |
| ↓←→ | ㅞ |
| ↑↓ | ㅚ |
| ↓↑ | ㅟ |
| →← | ㅐ |
| →←→← | ㅒ |
| ←→ | ㅔ |
| ←→←→ | ㅖ |
| 길게 가로획 다음 세로획 | ㅢ |

ㅢ도 양방향이다. 긴 →↑, →↓, ←↑, ←↓ 네 조합 모두 ㅢ가 된다.

긴 획으로 시작해도 ㅢ 외의 조합은 길이를 무시한다. 길게 →← 는 ㅐ,
길게 ↑→ 는 ㅘ, 길게 ↓← 는 ㅝ가 된다.

## 빌드 및 테스트

```bash
# 빌드
xcodebuild -scheme MoakiKeyboard -destination 'platform=iOS Simulator,name=iPhone 15'

# 테스트
xcodebuild test -scheme MoakiKeyboardTests -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 키보드 테스트 방법

1. 시뮬레이터에서 앱 실행
2. 설정 → 일반 → 키보드 → 키보드 → 새 키보드 추가 → MoakiKeyboard
3. 메모 앱에서 키보드 전환 (🌐 버튼)

## 주의사항

- iOS 키보드 익스텐션은 제한된 메모리에서 동작
- `KeyboardViewController`는 UIKit, 나머지는 SwiftUI
- 다크모드 대응: `Color(.systemBackground)` 계열 사용
- `insertText()` 호출 전 `flushCommittedText()`로 확정 텍스트 획득 필수
