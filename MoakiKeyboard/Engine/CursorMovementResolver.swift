import CoreGraphics

struct CursorMove: Equatable {
    let horizontalSteps: Int
    let verticalSteps: Int

    static let zero = CursorMove(horizontalSteps: 0, verticalSteps: 0)
}

enum CursorVerticalDirection {
    case up
    case down
}

struct CursorMovementResolver {
    private let horizontalStep: CGFloat
    private let verticalStep: CGFloat
    private let verticalFallbackStride: Int
    private let maximumStepsPerUpdate: Int

    private var lastTranslation = CGSize.zero
    private var horizontalRemainder: CGFloat = 0
    private var verticalRemainder: CGFloat = 0

    init(
        horizontalStep: CGFloat = KeyboardMetrics.cursorHorizontalStep,
        verticalStep: CGFloat = KeyboardMetrics.cursorVerticalStep,
        verticalFallbackStride: Int = KeyboardMetrics.cursorVerticalFallbackStride,
        maximumStepsPerUpdate: Int = KeyboardMetrics.cursorMaximumStepsPerUpdate
    ) {
        self.horizontalStep = horizontalStep
        self.verticalStep = verticalStep
        self.verticalFallbackStride = verticalFallbackStride
        self.maximumStepsPerUpdate = max(1, maximumStepsPerUpdate)
    }

    mutating func reset() {
        lastTranslation = .zero
        horizontalRemainder = 0
        verticalRemainder = 0
    }

    mutating func resolve(translation: CGSize) -> CursorMove {
        let delta = CGSize(
            width: translation.width - lastTranslation.width,
            height: translation.height - lastTranslation.height
        )
        lastTranslation = translation

        let horizontalResolution = Self.resolveSteps(
            delta: delta.width,
            step: horizontalStep,
            remainder: horizontalRemainder,
            maximumSteps: maximumStepsPerUpdate
        )
        horizontalRemainder = horizontalResolution.remainder

        let verticalResolution = Self.resolveSteps(
            delta: delta.height,
            step: verticalStep,
            remainder: verticalRemainder,
            maximumSteps: maximumStepsPerUpdate
        )
        verticalRemainder = verticalResolution.remainder

        return CursorMove(
            horizontalSteps: horizontalResolution.steps,
            verticalSteps: verticalResolution.steps
        )
    }

    func verticalOffset(
        direction: CursorVerticalDirection,
        contextBefore: String?,
        contextAfter: String?
    ) -> Int {
        switch direction {
        case .up:
            return upwardOffset(contextBefore: contextBefore)
        case .down:
            return downwardOffset(
                contextBefore: contextBefore,
                contextAfter: contextAfter
            )
        }
    }

    private static func resolveSteps(
        delta: CGFloat,
        step: CGFloat,
        remainder: CGFloat,
        maximumSteps: Int
    ) -> (steps: Int, remainder: CGFloat) {
        guard step > 0, delta != 0 else { return (0, remainder) }

        let updatedRemainder = remainder + delta
        let rawSteps = Int(updatedRemainder / step)
        guard rawSteps != 0 else { return (0, updatedRemainder) }

        if abs(rawSteps) > maximumSteps {
            let cappedSteps = rawSteps > 0 ? maximumSteps : -maximumSteps
            return (
                cappedSteps,
                updatedRemainder.truncatingRemainder(dividingBy: step)
            )
        }

        return (rawSteps, updatedRemainder - CGFloat(rawSteps) * step)
    }

    private func upwardOffset(contextBefore: String?) -> Int {
        guard let contextBefore else { return -verticalFallbackStride }
        guard !contextBefore.isEmpty else { return 0 }
        guard let newline = contextBefore.lastIndex(of: "\n") else {
            return -verticalFallbackStride
        }

        let currentLineStart = contextBefore.index(after: newline)
        let currentColumn = contextBefore[currentLineStart...].count
        let previousContent = contextBefore[..<newline]
        let previousLineStart = previousContent.lastIndex(of: "\n").map {
            previousContent.index(after: $0)
        } ?? previousContent.startIndex
        let previousLineLength = previousContent[previousLineStart...].count
        let targetColumn = min(currentColumn, previousLineLength)

        return -(currentColumn + 1 + previousLineLength - targetColumn)
    }

    private func downwardOffset(contextBefore: String?, contextAfter: String?) -> Int {
        guard let contextAfter else { return verticalFallbackStride }
        guard !contextAfter.isEmpty else { return 0 }
        guard let newline = contextAfter.firstIndex(of: "\n") else {
            return verticalFallbackStride
        }
        guard let contextBefore else { return verticalFallbackStride }

        let currentLineStart = contextBefore.lastIndex(of: "\n").map {
            contextBefore.index(after: $0)
        } ?? contextBefore.startIndex
        let currentColumn = contextBefore[currentLineStart...].count
        let currentLineSuffixLength = contextAfter[..<newline].count
        let nextLineStart = contextAfter.index(after: newline)
        let remainingContext = contextAfter[nextLineStart...]
        let nextLineEnd = remainingContext.firstIndex(of: "\n") ?? remainingContext.endIndex
        let nextLineLength = remainingContext[..<nextLineEnd].count
        let targetColumn = min(currentColumn, nextLineLength)

        return currentLineSuffixLength + 1 + targetColumn
    }
}
