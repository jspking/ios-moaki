import SwiftUI

struct SpaceBarView: View {
    let width: CGFloat
    let height: CGFloat
    let interactionResetGeneration: UInt64
    let onTap: () -> Void
    let onCursorModeBegan: () -> Void
    let onCursorMove: (CGSize) -> Void
    let onCursorModeEnded: () -> Void

    @State private var tracker = SpaceCursorGestureTracker()
    @State private var longPressTask: Task<Void, Never>?
    @State private var latestTranslation = CGSize.zero

    private var isPressed: Bool {
        tracker.state != .idle
    }

    private var isCursorMode: Bool {
        tracker.state == .cursorMode
    }

    var body: some View {
        Text(isCursorMode ? "커서 이동" : "space")
            .font(.system(size: 16, weight: isCursorMode ? .medium : .regular))
            .foregroundColor(isCursorMode ? .primary : .secondary)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged(handleDragChanged)
                    .onEnded { _ in handleDragEnded() }
            )
            .onChange(of: interactionResetGeneration) { _, _ in
                cancelGesture()
            }
            .onDisappear {
                cancelGesture()
            }
    }

    private var backgroundColor: Color {
        if isCursorMode {
            return Color.accentColor.opacity(0.28)
        }
        return isPressed ? Color(.systemGray4) : Color(.systemGray5)
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        if tracker.state == .idle {
            _ = tracker.touchDown()
            scheduleLongPress(generation: tracker.generation)
        }

        latestTranslation = value.translation
        handle(tracker.dragChanged(translation: value.translation))
    }

    private func handleDragEnded() {
        longPressTask?.cancel()
        longPressTask = nil
        handle(tracker.touchEnded())
        latestTranslation = .zero
    }

    private func scheduleLongPress(generation: UInt64) {
        longPressTask?.cancel()
        longPressTask = Task { @MainActor in
            do {
                try await Task.sleep(
                    nanoseconds: UInt64(KeyboardMetrics.spaceLongPressDuration * 1_000_000_000)
                )
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            let action = tracker.longPressFired(generation: generation)
            handle(action)
        }
    }

    private func cancelGesture() {
        longPressTask?.cancel()
        longPressTask = nil
        handle(tracker.cancelled())
        latestTranslation = .zero
    }

    private func handle(_ action: SpaceCursorAction) {
        switch action {
        case .insertSpace:
            onTap()
        case .cursorModeBegan:
            onCursorModeBegan()
            onCursorMove(latestTranslation)
        case .moveCursor(let translation):
            onCursorMove(translation)
        case .cursorModeEnded:
            onCursorModeEnded()
        case .none:
            break
        }
    }
}
