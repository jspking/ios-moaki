import SwiftUI

struct KeyboardSettingsView: View {
    private let preferences: SharedKeyboardPreferences
    @State private var deletionUnit: DeletionUnit
    @State private var baseGestureLength: CGFloat
    @State private var longStrokeLength: CGFloat

    init(preferences: SharedKeyboardPreferences = SharedKeyboardPreferences()) {
        self.preferences = preferences
        _deletionUnit = State(initialValue: preferences.deletionUnit)
        _baseGestureLength = State(initialValue: preferences.baseGestureLength)
        _longStrokeLength = State(initialValue: preferences.longStrokeLength)
    }

    private var longStrokeLowerBound: CGFloat {
        max(
            SharedKeyboardPreferences.longStrokeLengthRange.lowerBound,
            baseGestureLength + SharedKeyboardPreferences.minimumLongStrokeMargin
        )
    }

    private var isUsingDefaultLengths: Bool {
        baseGestureLength == SharedKeyboardPreferences.defaultBaseGestureLength
            && longStrokeLength == SharedKeyboardPreferences.defaultLongStrokeLength
    }

    var body: some View {
        Form {
            Section {
                Picker("지우기 단위", selection: $deletionUnit) {
                    ForEach(DeletionUnit.allCases) { unit in
                        Text(unit.settingsTitle)
                            .tag(unit)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityLabel("백스페이스 지우기 단위")
            } header: {
                Text("백스페이스")
            } footer: {
                Text(deletionUnit.settingsDescription)
            }

            Section("동작 예시") {
                LabeledContent("자모별", value: "값 → 갑 → 가 → ㄱ")
                LabeledContent("글자별", value: "값 → 삭제")
            }

            Section {
                lengthSlider(
                    title: "기본 모음 최소 거리",
                    value: $baseGestureLength,
                    range: SharedKeyboardPreferences.baseGestureLengthRange,
                    description: "ㅏ ㅓ ㅗ ㅜ 를 인식하기 시작하는 거리입니다. 짧게 잡으면 살짝만 밀어도 모음이 붙고, 길게 잡으면 자음만 누르기가 쉬워집니다."
                )

                lengthSlider(
                    title: "ㅡ ㅣ 긴 획 기준",
                    value: $longStrokeLength,
                    range: longStrokeLowerBound...SharedKeyboardPreferences.longStrokeLengthRange.upperBound,
                    description: "이 거리를 넘겨 밀면 ㅏ ㅓ 대신 ㅡ, ㅗ ㅜ 대신 ㅣ 가 입력됩니다. 긴 획은 방향을 가리지 않습니다."
                )

                Button("기본값으로 되돌리기") {
                    baseGestureLength = SharedKeyboardPreferences.defaultBaseGestureLength
                    longStrokeLength = SharedKeyboardPreferences.defaultLongStrokeLength
                }
                .disabled(isUsingDefaultLengths)
            } header: {
                Text("제스처 길이")
            } footer: {
                Text("긴 획 기준은 항상 기본 거리보다 \(Int(SharedKeyboardPreferences.minimumLongStrokeMargin))pt 이상 크게 유지됩니다.")
            }

            Section("모음 입력 방법") {
                LabeledContent("ㅏ ㅓ ㅗ ㅜ", value: "짧게 → ← ↑ ↓")
                LabeledContent("ㅡ", value: "길게 → 또는 ←")
                LabeledContent("ㅣ", value: "길게 ↑ 또는 ↓")
                LabeledContent("ㅢ", value: "길게 가로획 다음 세로획")
            }
        }
        .navigationTitle("키보드 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: deletionUnit) { _, newValue in
            preferences.deletionUnit = newValue
        }
        .onChange(of: baseGestureLength) { _, newValue in
            preferences.baseGestureLength = newValue
            // Raising the base length can push the long-stroke floor upward.
            if longStrokeLength < longStrokeLowerBound {
                longStrokeLength = longStrokeLowerBound
            }
        }
        .onChange(of: longStrokeLength) { _, newValue in
            preferences.longStrokeLength = newValue
        }
    }

    @ViewBuilder
    private func lengthSlider(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: range, step: 1) {
                Text(title)
            } minimumValueLabel: {
                Text("\(Int(range.lowerBound))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("\(Int(range.upperBound))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(title)
            .accessibilityValue("\(Int(value.wrappedValue.rounded()))포인트")

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private extension DeletionUnit {
    var settingsTitle: String {
        switch self {
        case .compositionStep:
            return "자모별"
        case .character:
            return "글자별"
        }
    }

    var settingsDescription: String {
        switch self {
        case .compositionStep:
            return "한글을 자모 조합 단계로 지웁니다. 복합 모음과 겹받침도 단계별로 되돌립니다."
        case .character:
            return "한글 조합 상태와 관계없이 한 번에 한 글자씩 지웁니다."
        }
    }
}

#Preview {
    NavigationStack {
        KeyboardSettingsView()
    }
}
