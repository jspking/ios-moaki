// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MoakiKeyboardCore",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "MoakiKeyboardCore",
            path: "MoakiKeyboard",
            exclude: [
                "Info.plist",
                "KeyboardViewController.swift",
                "Utilities/KeyboardSettings.swift",
                "Views"
            ],
            sources: [
                "Engine/GestureAnalyzer.swift",
                "Engine/HangulComposer.swift",
                "Engine/CursorMovementResolver.swift",
                "Engine/SpaceCursorGestureTracker.swift",
                "Engine/VowelResolver.swift",
                "Models/GestureDirection.swift",
                "Models/HangulJamo.swift",
                "Models/VowelPattern.swift",
                "Utilities/HangulConstants.swift",
                "Utilities/KeyboardMetrics.swift",
                "ViewModels/KeyboardViewModel.swift"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "MoakiKeyboardCoreTests",
            dependencies: ["MoakiKeyboardCore"],
            path: "MoakiKeyboardTests",
            exclude: [
                "GestureAnalyzerTests.swift",
                "HangulComposerTests.swift",
                "KeyboardViewModelLongPressTests.swift",
                "VowelResolverTests.swift"
            ],
            sources: [
                "CursorMovementResolverTests.swift",
                "GestureDirectionToleranceTests.swift",
                "KeyboardMetricsLayoutTests.swift",
                "KeyboardViewModelCursorTests.swift",
                "SpaceCursorGestureTrackerTests.swift"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
