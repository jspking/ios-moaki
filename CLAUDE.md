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

### 각도와 길이로 판정

기본 모음 ㅏ/ㅓ/ㅗ/ㅜ는 각자의 기준축을 중심으로 좌우 `KeyboardMetrics.cardinalHalfAngle`(30°)씩
동일한 폭을 갖는다. 각도 기준은 `오른쪽=0°`, `위=90°`, `왼쪽=180°`, `아래=270°`이다.

ㅣ(↗)와 ㅡ(↘)는 그 사이에 남은 구간을 가져가되, 획 길이가
`KeyboardMetrics.diagonalThreshold`(55pt) 이상일 때만 확정된다. 그보다 짧으면 가장 가까운
기본 모음으로 판정한다.

- 기준축에서 30° 이내는 길이와 무관하게 항상 기본 모음이다. 길게 그은 ㅏ는 ㅣ로 바뀌지 않는다.
- ↖와 ↙는 대응하는 모음이 없으므로, 길이와 무관하게 가장 가까운 기본 모음으로 판정한다.
- 첫 획은 두 번째 획이 시작되기 전까지 시작점 기준으로 계속 다시 판정된다. 손가락이 55pt를
  넘어가는 순간 ㅗ가 ㅣ로 바뀔 수 있어야 하기 때문이다.
- 축과 축 사이 정확히 중간인 획은 ㅗ/ㅜ로 판정한다.

### 기본 모음

| 방향 | 모음 | 조건 |
|------|------|------|
| → | ㅏ | 0° ± 30° |
| ← | ㅓ | 180° ± 30° |
| ↑ | ㅗ | 90° ± 30° |
| ↓ | ㅜ | 270° ± 30° |
| ↗ | ㅣ | 30°~60°, 55pt 이상 |
| ↘ | ㅡ | 300°~330°, 55pt 이상 |

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
| ↓→← | ㅞ |
| ↑↓ | ㅚ |
| ↓↑ | ㅟ |
| →← | ㅐ |
| →←→← | ㅒ |
| ←→ | ㅔ |
| ←→←→ | ㅖ |
| ↘↖ 또는 ↘↑ | ㅢ | (↘는 55pt 이상)

## 빌드 및 테스트

```bash
# 빌드
xcodebuild -scheme MoakiKeyboard -destination 'platform=iOS Simulator,name=iPhone 15'

# 테스트 (조합 로직은 SwiftPM 으로 macOS 에서 바로 돌린다. 시뮬레이터 불필요)
swift test
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
