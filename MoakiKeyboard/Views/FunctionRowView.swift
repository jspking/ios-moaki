import SwiftUI

struct FunctionRowView: View {
    let totalWidth: CGFloat
    let isSymbolMode: Bool
    let onToggleModePressed: () -> Void
    let onCommaPressed: () -> Void
    let onSpacePressed: () -> Void
    let onCursorModeBegan: () -> Void
    let onCursorMove: (CGSize) -> Void
    let onCursorModeEnded: () -> Void
    let onReturnPressed: () -> Void
    let interactionResetGeneration: UInt64

    private let spacing: CGFloat = KeyboardMetrics.keySpacing
    private let height: CGFloat = KeyboardMetrics.functionRowHeight

    var body: some View {
        HStack(spacing: spacing) {
            // 123/한글 toggle button
            FunctionKeyView(
                content: AnyView(
                    Text(isSymbolMode ? "한글" : "123")
                        .font(.system(size: 16, weight: .medium))
                ),
                width: toggleWidth,
                height: height,
                action: onToggleModePressed
            )

            // Comma key (left of space)
            FunctionKeyView(
                content: AnyView(
                    Text(",")
                        .font(.system(size: 20))
                ),
                width: commaWidth,
                height: height,
                action: onCommaPressed
            )

            // Space bar
            SpaceBarView(
                width: spaceWidth,
                height: height,
                interactionResetGeneration: interactionResetGeneration,
                onTap: onSpacePressed,
                onCursorModeBegan: onCursorModeBegan,
                onCursorMove: onCursorMove,
                onCursorModeEnded: onCursorModeEnded
            )

            // Return button
            FunctionKeyView(
                content: AnyView(
                    Image(systemName: "return")
                        .font(.system(size: 20))
                ),
                width: returnWidth,
                height: height,
                action: onReturnPressed
            )
        }
    }

    private var returnWidth: CGFloat {
        // Match backspace width: right symbol + center key + spacing.
        let centerKeyWidth = KeyboardMetrics.centerKeyWidth(for: totalWidth)
        return KeyboardMetrics.rightSymbolKeyWidth + centerKeyWidth + KeyboardMetrics.keySpacing
    }

    private var availableWidthWithoutReturn: CGFloat {
        // Three gaps between four buttons plus the two outer padding gaps.
        totalWidth - returnWidth - spacing * 5
    }

    private var toggleWidth: CGFloat {
        availableWidthWithoutReturn * 0.30
    }

    private var commaWidth: CGFloat {
        availableWidthWithoutReturn * 0.14
    }

    private var spaceWidth: CGFloat {
        availableWidthWithoutReturn * 0.56
    }
}

struct FunctionKeyView: View {
    let content: AnyView
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        content
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius)
                    .fill(isPressed ? Color(.systemGray4) : Color(.systemGray5))
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Korean Mode")
            .font(.headline)
        FunctionRowView(
            totalWidth: 350,
            isSymbolMode: false,
            onToggleModePressed: { print("Toggle") },
            onCommaPressed: { print("Comma") },
            onSpacePressed: { print("Space") },
            onCursorModeBegan: { print("Cursor began") },
            onCursorMove: { print("Cursor moved: \($0)") },
            onCursorModeEnded: { print("Cursor ended") },
            onReturnPressed: { print("Return") },
            interactionResetGeneration: 0
        )

        Text("Symbol Mode")
            .font(.headline)
        FunctionRowView(
            totalWidth: 350,
            isSymbolMode: true,
            onToggleModePressed: { print("Toggle") },
            onCommaPressed: { print("Comma") },
            onSpacePressed: { print("Space") },
            onCursorModeBegan: { print("Cursor began") },
            onCursorMove: { print("Cursor moved: \($0)") },
            onCursorModeEnded: { print("Cursor ended") },
            onReturnPressed: { print("Return") },
            interactionResetGeneration: 0
        )
    }
    .padding()
    .background(Color(.systemGray6))
}
