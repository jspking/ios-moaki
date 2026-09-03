import Combine
import CoreGraphics
import Foundation

@MainActor
final class KeyboardViewModel: ObservableObject {
    @Published var activeKey: (row: Int, column: Int)?
    @Published var previewVowel: Jungseong?
    @Published var gestureDirections: [GestureDirection] = []
    @Published var gestureStartPoint: CGPoint?
    @Published var isSymbolMode = false
    @Published private(set) var interactionResetGeneration: UInt64 = 0

    private let composer = HangulComposer()
    private let gestureAnalyzer = GestureAnalyzer()
    private let vowelResolver = VowelResolver()
    private var cursorMovementResolver = CursorMovementResolver()
    private var lastComposingText = ""

    private(set) var deletionUnit: DeletionUnit
    private var activeBackspaceDeletionUnit: DeletionUnit?

    private let backspaceRepeatInitialDelay: TimeInterval
    private let backspaceRepeatInterval: TimeInterval
    private var isBackspacePressing = false
    private var backspaceInitialDelayTask: Task<Void, Never>?
    private var backspaceRepeatTask: Task<Void, Never>?
    private var didHandleLongPressNumberInCurrentGesture = false

    weak var delegate: KeyboardViewModelDelegate?

    init(
        deletionUnit: DeletionUnit = .compositionStep,
        backspaceRepeatInitialDelay: TimeInterval = 0.4,
        backspaceRepeatInterval: TimeInterval = 0.08
    ) {
        self.deletionUnit = deletionUnit
        self.backspaceRepeatInitialDelay = backspaceRepeatInitialDelay
        self.backspaceRepeatInterval = backspaceRepeatInterval
    }

    deinit {
        backspaceInitialDelayTask?.cancel()
        backspaceRepeatTask?.cancel()
    }

    var composingText: String {
        composer.displayText
    }

    // MARK: - Mode Toggle

    func toggleMode() {
        stopBackspaceRepeat()
        commitCurrent()
        isSymbolMode.toggle()
        triggerHapticFeedback()
    }

    // MARK: - Input Methods

    func inputConsonant(_ consonant: Choseong) {
        let action = composer.inputChoseong(consonant)
        handleComposerAction(action)
        triggerHapticFeedback()
    }

    func inputVowel(_ vowel: Jungseong) {
        let action = composer.inputJungseong(vowel)
        handleComposerAction(action)
        triggerHapticFeedback()
    }

    func inputSymbol(_ symbol: String) {
        commitCurrent()
        delegate?.insertText(symbol)
        triggerHapticFeedback()
    }

    func inputNumber(_ number: String) {
        commitCurrent()
        delegate?.insertText(number)
        triggerHapticFeedback()
    }

    func inputLongPressNumber(_ number: String) {
        didHandleLongPressNumberInCurrentGesture = true
        inputNumber(number)
    }

    func deleteBackward() {
        deleteBackward(using: deletionUnit)
        triggerHapticFeedback()
    }

    func applyDeletionUnit(_ deletionUnit: DeletionUnit) {
        guard self.deletionUnit != deletionUnit else { return }
        stopBackspaceRepeat()
        commitCurrent()
        self.deletionUnit = deletionUnit
    }

    func inputSpace() {
        commitAndInsert(" ")
        triggerHapticFeedback()
    }

    func inputReturn() {
        commitAndInsert("\n")
        triggerHapticFeedback()
    }

    func switchKeyboard() {
        prepareForKeyboardSwitch()
        delegate?.switchToNextKeyboard()
    }

    func prepareForKeyboardSwitch() {
        stopBackspaceRepeat()
        commitCurrent()
    }

    func beginBackspacePress() {
        guard !isBackspacePressing else { return }
        isBackspacePressing = true
        activeBackspaceDeletionUnit = deletionUnit
        deleteBackward(using: deletionUnit)
        triggerHapticFeedback()
        startBackspaceRepeat()
    }

    func endBackspacePress() {
        stopBackspaceRepeat()
    }

    // MARK: - Space Cursor Movement

    func beginCursorMovement() {
        stopBackspaceRepeat()
        commitCurrent()
        cursorMovementResolver.reset()
        triggerHapticFeedback()
    }

    func moveCursor(translation: CGSize) {
        let movement = cursorMovementResolver.resolve(translation: translation)

        if movement.horizontalSteps != 0 {
            delegate?.moveCursor(byCharacterOffset: movement.horizontalSteps)
        }

        guard movement.verticalSteps != 0 else { return }
        let direction: CursorVerticalDirection = movement.verticalSteps < 0 ? .up : .down

        for _ in 0..<abs(movement.verticalSteps) {
            guard let delegate else { return }
            let offset = cursorMovementResolver.verticalOffset(
                direction: direction,
                contextBefore: delegate.documentContextBeforeInput,
                contextAfter: delegate.documentContextAfterInput
            )
            guard offset != 0 else { break }
            delegate.moveCursor(byCharacterOffset: offset)
        }
    }

    func endCursorMovement() {
        cursorMovementResolver.reset()
    }

    // MARK: - Gesture Handling

    func gestureStarted(row: Int, column: Int, at point: CGPoint) {
        didHandleLongPressNumberInCurrentGesture = false
        activeKey = (row, column)
        gestureStartPoint = point
        gestureAnalyzer.reset()
        gestureAnalyzer.addPoint(point)
        gestureDirections = []
        previewVowel = nil
    }

    func gestureMoved(to point: CGPoint) {
        gestureAnalyzer.addPoint(point)
        let directions = gestureAnalyzer.getDirections()
        gestureDirections = directions
        previewVowel = vowelResolver.peekVowel(directions: directions)
    }

    func gestureEnded(row: Int, column: Int) {
        if didHandleLongPressNumberInCurrentGesture {
            didHandleLongPressNumberInCurrentGesture = false
            resetGestureState()
            return
        }

        if isSymbolMode {
            handleSymbolModeTap(row: row, column: column)
        } else {
            handleKoreanModeGesture(row: row, column: column)
        }
        resetGestureState()
    }

    private func handleSymbolModeTap(row: Int, column: Int) {
        guard let content = KeyboardMetrics.keyContent(
            at: row,
            column: column,
            isSymbolMode: true
        ) else { return }

        switch content {
        case .symbol(let symbol):
            inputSymbol(symbol)
        case .backspace:
            deleteBackward()
        case .consonant:
            break
        }
    }

    private func handleKoreanModeGesture(row: Int, column: Int) {
        let directions = gestureAnalyzer.finalizeGesture()
        guard let content = KeyboardMetrics.keyContent(
            at: row,
            column: column,
            isSymbolMode: false
        ) else { return }

        switch content {
        case .consonant(let consonant):
            if directions.isEmpty {
                inputConsonant(consonant)
            } else {
                inputConsonant(consonant)
                let resolution = vowelResolver.resolve(directions: directions)
                if let vowel = resolution.vowel {
                    inputVowel(vowel)
                }
            }
        case .symbol(let symbol):
            inputSymbol(symbol)
        case .backspace:
            deleteBackward()
        }
    }

    // MARK: - Public State Reset

    func resetComposer() {
        stopBackspaceRepeat()
        endCursorMovement()
        interactionResetGeneration &+= 1
        lastComposingText = ""
        composer.reset()
    }

    func resetGestureState() {
        stopBackspaceRepeat()
        endCursorMovement()
        interactionResetGeneration &+= 1
        didHandleLongPressNumberInCurrentGesture = false
        activeKey = nil
        gestureStartPoint = nil
        gestureDirections = []
        previewVowel = nil
        gestureAnalyzer.reset()
    }

    // MARK: - Private Helpers

    private func handleComposerAction(_ action: HangulComposer.ComposerAction) {
        switch action {
        case .none:
            break
        case .update:
            updateComposingText()
        case .commit, .commitAndUpdate, .commitAndCommit:
            let committed = composer.flushCommittedText()
            for _ in lastComposingText {
                delegate?.deleteBackward()
            }
            lastComposingText = ""
            if !committed.isEmpty {
                delegate?.insertText(committed)
            }
            updateComposingText()
        case .delete:
            if !lastComposingText.isEmpty {
                for _ in lastComposingText {
                    delegate?.deleteBackward()
                }
                lastComposingText = ""
            } else {
                delegate?.deleteBackward()
            }
            updateComposingText()
        }
    }

    private func updateComposingText() {
        let composing = composer.currentComposingCharacter.map { String($0) } ?? ""
        let previous = lastComposingText
        lastComposingText = composing
        delegate?.updateComposingText(from: previous, to: composing)
    }

    private func commitCurrent() {
        lastComposingText = ""
        composer.reset()
    }

    private func commitAndInsert(_ text: String) {
        commitCurrent()
        delegate?.insertText(text)
    }

    private func triggerHapticFeedback() {
        delegate?.triggerHapticFeedback()
    }

    private func deleteBackward(using deletionUnit: DeletionUnit) {
        guard delegate?.selectedText?.isEmpty != false else {
            commitCurrent()
            delegate?.deleteBackward()
            return
        }

        switch deletionUnit {
        case .compositionStep:
            deleteCompositionStep()
        case .character:
            deleteCharacter()
        }
    }

    private func deleteCompositionStep() {
        let action = composer.deleteBackward()
        if action != .none {
            handleComposerAction(action)
            return
        }

        guard let lastCharacter = delegate?.documentContextBeforeInput?.last,
              composer.resumeComposing(lastCharacter) else {
            delegate?.deleteBackward()
            return
        }

        delegate?.deleteBackward()
        handleComposerAction(composer.deleteBackward())
    }

    private func deleteCharacter() {
        guard composer.currentComposingCharacter != nil || !lastComposingText.isEmpty else {
            delegate?.deleteBackward()
            return
        }

        composer.reset()
        updateComposingText()
    }

    func repeatBackspaceIfNeeded() {
        guard isBackspacePressing,
              let activeBackspaceDeletionUnit else { return }
        deleteBackward(using: activeBackspaceDeletionUnit)
        triggerHapticFeedback()
    }

    private func startBackspaceRepeat() {
        backspaceInitialDelayTask?.cancel()
        backspaceInitialDelayTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(
                    nanoseconds: UInt64(self.backspaceRepeatInitialDelay * 1_000_000_000)
                )
            } catch {
                return
            }

            guard self.isBackspacePressing else { return }
            self.backspaceRepeatTask?.cancel()
            self.backspaceRepeatTask = Task { @MainActor [weak self] in
                while let self, self.isBackspacePressing {
                    do {
                        try await Task.sleep(
                            nanoseconds: UInt64(self.backspaceRepeatInterval * 1_000_000_000)
                        )
                    } catch {
                        return
                    }

                    guard self.isBackspacePressing else { return }
                    self.repeatBackspaceIfNeeded()
                }
            }
        }
    }

    private func stopBackspaceRepeat() {
        isBackspacePressing = false
        backspaceInitialDelayTask?.cancel()
        backspaceInitialDelayTask = nil
        backspaceRepeatTask?.cancel()
        backspaceRepeatTask = nil
        activeBackspaceDeletionUnit = nil
    }
}

@MainActor
protocol KeyboardViewModelDelegate: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    var selectedText: String? { get }

    func insertText(_ text: String)
    func deleteBackward()
    func updateComposingText(from previous: String, to current: String)
    func moveCursor(byCharacterOffset offset: Int)
    func switchToNextKeyboard()
    func triggerHapticFeedback()
}

extension KeyboardViewModelDelegate {
    var documentContextBeforeInput: String? { nil }
    var documentContextAfterInput: String? { nil }
    var selectedText: String? { nil }
    func moveCursor(byCharacterOffset offset: Int) {}
}
