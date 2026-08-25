import CoreGraphics

enum SpaceCursorAction: Equatable {
    case insertSpace
    case cursorModeBegan
    case moveCursor(CGSize)
    case cursorModeEnded
    case none
}

struct SpaceCursorGestureTracker {
    enum State: Equatable {
        case idle
        case pressing
        case cursorMode
    }

    private(set) var state: State = .idle
    private(set) var generation: UInt64 = 0

    private let dragThreshold: CGFloat
    private var didDrag = false

    init(dragThreshold: CGFloat = KeyboardMetrics.spaceDragThreshold) {
        self.dragThreshold = dragThreshold
    }

    mutating func touchDown() -> SpaceCursorAction {
        generation &+= 1
        state = .pressing
        didDrag = false
        return .none
    }

    mutating func dragChanged(translation: CGSize) -> SpaceCursorAction {
        guard state != .idle else { return .none }

        let distance = hypot(translation.width, translation.height)
        if distance >= dragThreshold {
            didDrag = true
        }

        guard state == .cursorMode else { return .none }
        return .moveCursor(translation)
    }

    mutating func longPressFired(generation expectedGeneration: UInt64) -> SpaceCursorAction {
        guard state == .pressing, generation == expectedGeneration else { return .none }

        state = .cursorMode
        return .cursorModeBegan
    }

    mutating func touchEnded() -> SpaceCursorAction {
        let action: SpaceCursorAction

        switch state {
        case .idle:
            action = .none
        case .pressing:
            action = didDrag ? .none : .insertSpace
        case .cursorMode:
            action = .cursorModeEnded
        }

        reset()
        return action
    }

    mutating func cancelled() -> SpaceCursorAction {
        let action: SpaceCursorAction = state == .cursorMode ? .cursorModeEnded : .none
        reset()
        return action
    }

    private mutating func reset() {
        generation &+= 1
        state = .idle
        didDrag = false
    }
}
