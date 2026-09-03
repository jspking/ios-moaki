import SwiftUI
import UIKit

struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @ObservedObject var settings = KeyboardSettings.shared
    let onInputModeList: (UIView, UIEvent) -> Void

    var body: some View {
        GeometryReader { geometry in
            let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: geometry.size.width)
            let keyHeight = KeyboardMetrics.keyHeight(for: geometry.size.height)

            ZStack {
                VStack(spacing: KeyboardMetrics.keySpacing) {
                    KeyGridView(
                        centerKeyWidth: centerKeyWidth,
                        keyHeight: keyHeight,
                        totalWidth: geometry.size.width,
                        isSymbolMode: viewModel.isSymbolMode,
                        activeKey: viewModel.activeKey,
                        previewVowel: viewModel.previewVowel,
                        onConsonantTap: { viewModel.inputConsonant($0) },
                        onSymbolTap: { viewModel.inputSymbol($0) },
                        onBackspacePressStart: { viewModel.beginBackspacePress() },
                        onBackspacePressEnd: { viewModel.endBackspacePress() },
                        onLongPressNumber: { viewModel.inputLongPressNumber($0) },
                        onGestureStart: { row, column, point in
                            viewModel.gestureStarted(row: row, column: column, at: point)
                        },
                        onGestureMove: { viewModel.gestureMoved(to: $0) },
                        onGestureEnd: { row, column in
                            viewModel.gestureEnded(row: row, column: column)
                        }
                    )

                    FunctionRowView(
                        totalWidth: geometry.size.width,
                        isSymbolMode: viewModel.isSymbolMode,
                        onToggleModePressed: { viewModel.toggleMode() },
                        onInputModeList: onInputModeList,
                        onCommaPressed: { viewModel.inputSymbol(",") },
                        onSpacePressed: { viewModel.inputSpace() },
                        onCursorModeBegan: { viewModel.beginCursorMovement() },
                        onCursorMove: { viewModel.moveCursor(translation: $0) },
                        onCursorModeEnded: { viewModel.endCursorMovement() },
                        onReturnPressed: { viewModel.inputReturn() },
                        interactionResetGeneration: viewModel.interactionResetGeneration
                    )
                }
                .padding(KeyboardMetrics.keySpacing)

                if settings.showGesturePreview && !viewModel.isSymbolMode {
                    GestureOverlayView(
                        directions: viewModel.gestureDirections,
                        startPoint: viewModel.gestureStartPoint,
                        currentVowel: viewModel.previewVowel
                    )
                }
            }
            .background(Color(.systemGray6))
        }
    }
}

#Preview {
    KeyboardView(
        viewModel: KeyboardViewModel(),
        onInputModeList: { _, _ in }
    )
        .frame(height: 280)
}
