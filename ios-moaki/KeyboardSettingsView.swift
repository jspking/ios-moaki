import SwiftUI

struct KeyboardSettingsView: View {
    private let preferences: SharedKeyboardPreferences
    @State private var deletionUnit: DeletionUnit

    init(preferences: SharedKeyboardPreferences = SharedKeyboardPreferences()) {
        self.preferences = preferences
        _deletionUnit = State(initialValue: preferences.deletionUnit)
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
        }
        .navigationTitle("키보드 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: deletionUnit) { _, newValue in
            preferences.deletionUnit = newValue
        }
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
