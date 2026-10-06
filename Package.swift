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
                "MoakiKeyboard.entitlements",
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
                "Models/DeletionUnit.swift",
                "Utilities/HangulConstants.swift",
                "Utilities/KeyboardMetrics.swift",
                "Utilities/SharedKeyboardPreferences.swift",
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
            sources: [
                "CursorMovementResolverTests.swift",
                "GestureAnalyzerTests.swift",
                "VowelResolverTests.swift",
                "VowelGesturePathTests.swift",
                "GestureDirectionToleranceTests.swift",
                "HangulComposerDeletionTests.swift",
                "HangulComposerTests.swift",
                "KeyboardMetricsLayoutTests.swift",
                "KeyboardViewModelCursorTests.swift",
                "KeyboardViewModelDeletionTests.swift",
                "KeyboardViewModelDismissalTests.swift",
                "KeyboardViewModelLongPressTests.swift",
                "SharedKeyboardPreferencesTests.swift",
                "SpaceCursorGestureTrackerTests.swift"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
