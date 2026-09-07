# 긴 획으로 ㅡ와 ㅣ 입력하기 (설계)

작성일: 2026-09-07

## 배경

ㅡ와 ㅣ는 지금까지 오른쪽 대각선 한 획(↘, ↗)으로 입력했다. 그런데
`GestureDirection.from`은 ㅗ와 ㅜ의 인식 여유를 확보하려고 각도 경계를
비대칭으로 잡아 두었기 때문에(오른쪽 위 30도부터 ↗), 사용자가 의도한
기울기와 실제 판정이 어긋나는 일이 잦았다. 수직으로 그으려던 획이 ㅣ가
되거나, 대각선으로 그으려던 획이 ㅗ가 된다.

방향 대신 **획 길이**로 ㅡ와 ㅣ를 구분하면 이 문제가 사라진다. 사용자는
기울기를 신경 쓰지 않고, 짧게 그을지 길게 그을지만 결정하면 된다.

## 결정 사항

| 항목 | 결정 |
|------|------|
| 짧은 → | ㅏ (기존과 같음) |
| 긴 → | ㅡ |
| 짧은 ↑ | ㅗ (기존과 같음) |
| 긴 ↑ | ㅣ |
| 긴 → 다음 ↑ | ㅢ |
| 기존 대각선 방식 | 제거. 대각선 네 방향 모두 수직으로 정규화 |
| 긴 획 뒤에 다른 획이 이어질 때 | ㅢ만 예외로 두고, 나머지는 길이를 버리고 기존 패턴으로 판정 |
| 설정 항목 | 슬라이더 두 개 (기본 모음 최소 거리, 긴 획 기준) |

## 발견 사항: 기존 길이 기록은 쓸 수 없다

`GestureAnalyzer`는 `directionMagnitudes`에 획별 거리를 기록하지만, 이
값은 획의 전체 길이가 아니다. `analyzeLatestMovement()`는 같은 방향이
이어질 때 `newDirection != lastDirection` 조건에 걸려 아무것도 갱신하지
않으므로, 기록된 값은 "그 방향이 처음 인식된 순간의 거리"에 머문다.
손가락을 200pt 끌어도 25pt로 남는다.

따라서 획 길이 측정을 새로 구현해야 한다. 이것이 이 작업의 핵심이다.

부수적으로, 같은 방향이 연속으로 append 되지 않으므로
`collapseConsecutiveDuplicates`의 크기 갱신 분기도 현재는 도달하지 않는
코드다.

## 구조

### 1. 획 길이 측정 (`GestureAnalyzer`)

획마다 시작점을 따로 보관하고, 같은 방향이 이어지는 동안 시작점에서
현재 점까지의 최대 거리로 길이를 갱신한다.

```swift
struct GestureStroke {
    let direction: GestureDirection
    let length: CGFloat
}

func finalizeStrokes() -> [GestureStroke]
```

기존 `finalizeGesture() -> [GestureDirection]`은 `finalizeStrokes()`의
방향만 뽑아내는 형태로 남긴다. 호출부와 기존 테스트가 그대로 동작한다.

임계값 세 개는 `let`에서 `var`로 바꾸고 `configure(base:)`로 함께
갱신한다.

### 2. 길이 판정 (`VowelResolver`)

기존 패턴 트라이는 그대로 두고, 긴 획 전용 표를 별도로 두어 먼저
조회한다.

```
긴 →        → ㅡ
긴 ↑        → ㅣ
긴 → 다음 ↑  → ㅢ
```

첫 획이 긴 획일 때만 이 표를 조회하고, 맞는 항목이 없으면 길이를 버리고
기존 트라이로 넘긴다. 그래서 긴 →← 는 ㅐ, 긴 ↑→ 는 ㅘ가 된다.

기존 트라이에 길이 차원을 넣어 재구성하는 방식은 채택하지 않았다. 변경
범위가 크고, 관용적 되돌리기 규칙을 표현하기 어렵다.

### 3. 대각선 정규화 (`VowelResolver.normalizeFirstStroke`)

첫 획의 대각선 네 개를 모두 수직으로 접는다.

- ↖, ↗ → ↑
- ↙, ↘ → ↓

두 번째 획 이후의 정규화 규칙(`normalizeTrailingStroke`)은 그대로 둔다.
복합 모음을 비스듬히 그어도 인식되는 관용성을 유지해야 한다.

`VowelPattern`에서 ㅡ(↘), ㅣ(↗), ㅢ(↘↖), ㅢ(↘↑) 항목을 삭제한다.

### 4. 설정 저장 (`SharedKeyboardPreferences`)

| 키 | 기본값 | 범위 |
|------|--------|------|
| `baseGestureLength` | 20pt | 10 ~ 40 |
| `longStrokeLength` | 70pt | 40 ~ 140 |

`longStrokeLength`는 읽을 때와 쓸 때 모두 `baseGestureLength + 10`
이상으로 보정한다. 두 값이 뒤집히면 짧은 획을 아예 입력할 수 없게 되기
때문이다.

`KeyboardPreferencesBacking`에 `object(forKey:)`를 추가한다. 값이 없는
상태와 0으로 저장된 상태를 구분해야 하므로 `double(forKey:)`만으로는
부족하다.

기본값 20pt는 현재 `KeyboardMetrics.gestureThreshold`와 같으므로,
설정을 건드리지 않으면 짧은 획 동작은 지금과 완전히 같다.

### 5. 임계값 비율 유지

현재 임계값 세 개는 20 / 10 / 30으로 1 : 0.5 : 1.5 비율을 이룬다. 이
비율을 유지하도록 기본 거리에서 나머지를 계산한다.

- `reversalThreshold = base * 0.5`
- `directionChangeThreshold = base * 1.5`

기본값 20pt에서 10과 30이 나오므로 현재 동작과 같다.

### 6. 설정 화면 (`KeyboardSettingsView`)

기존 백스페이스 섹션 아래에 제스처 섹션을 추가한다. 슬라이더 두 개,
현재 pt 값 표시, 기본값 복원 버튼을 둔다.

### 7. 확장으로 전달

`KeyboardViewController`가 이미 `viewWillAppear`에서
`applyDeletionUnit`을 호출하므로, 같은 자리에서
`applyGestureLengths(base:long:)`도 호출한다. `KeyboardViewModel`은 이
값으로 `GestureAnalyzer`를 다시 구성하고 `VowelResolver`에 긴 획 기준을
넘긴다.

### 8. 테스트

`GestureAnalyzerTests.swift`와 `VowelResolverTests.swift`는
`@testable import MoakiKeyboard`를 조건 없이 쓰고 있어서
`Package.swift`에서 제외되어 있다. 다른 테스트가 쓰는
`#if SWIFT_PACKAGE` 분기를 넣어 SPM 테스트 대상에 포함시킨다. 이 작업의
핵심 영역을 담당하는 파일이므로 명령줄에서 검증할 수 있어야 한다.

새로 추가할 검증 항목:

- 같은 방향으로 계속 끌었을 때 획 길이가 누적되는지
- 긴 → 가 ㅡ, 긴 ↑ 이 ㅣ가 되는지
- 짧은 → 가 여전히 ㅏ, 짧은 ↑ 이 여전히 ㅗ인지
- 긴 →↑ 가 ㅢ, 긴 →← 가 ㅐ, 긴 ↑→ 가 ㅘ인지
- 대각선 네 방향이 모두 수직으로 접히는지
- 설정값 저장과 하한 보정

### 9. 문서와 튜토리얼

`TutorialData.swift`의 대각선 카드와 ㅢ 항목, `README.md`,
`README_en.md`, `CLAUDE.md`의 제스처 표를 함께 수정한다.

## 남겨 두는 문제

각도 경계는 이번에 건드리지 않는다. `GestureDirection.from`의 오른쪽 위
30도 경계는 ㅗ와 ㅜ의 여유를 위해 일부러 비대칭으로 잡은 값이므로, 짧은
획 인식률을 지키려면 유지하는 편이 낫다.

그 결과로 **오른쪽으로 길게 끌면서 30도 이상 위로 기울면 ㅡ가 아니라
ㅣ가 된다.** 실제로 써 보고 이 부분이 걸리면, 긴 획에만 45도 대칭
경계를 적용하는 방식으로 따로 손본다. 지금 함께 바꾸면 짧은 획
인식률까지 동시에 흔들려서 원인 구분이 어려워진다.
