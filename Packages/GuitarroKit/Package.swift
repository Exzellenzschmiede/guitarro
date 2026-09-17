// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GuitarroKit",
    defaultLocalization: "en",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [
        .library(name: "MusicTheory", targets: ["MusicTheory"]),
        .library(name: "AudioEngine", targets: ["AudioEngine"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Fretboard", targets: ["Fretboard"]),
        .library(name: "Training", targets: ["Training"]),
        .library(name: "HandCoach", targets: ["HandCoach"]),
        .library(name: "Songs", targets: ["Songs"]),
        .library(name: "AICoach", targets: ["AICoach"]),
        .library(name: "Story", targets: ["Story"]),
    ],
    targets: [
        .target(name: "MusicTheory"),
        .target(name: "AudioEngine", dependencies: ["MusicTheory"]),
        .target(name: "DesignSystem"),
        .target(name: "Fretboard", dependencies: ["MusicTheory", "DesignSystem"]),
        .target(name: "Training", dependencies: ["MusicTheory"]),
        .target(name: "HandCoach"),
        .target(name: "Songs", dependencies: ["MusicTheory"]),
        .target(name: "AICoach", dependencies: ["MusicTheory"]),
        .target(name: "Story"),
        .testTarget(name: "MusicTheoryTests", dependencies: ["MusicTheory"]),
        .testTarget(name: "AudioEngineTests", dependencies: ["AudioEngine"]),
        .testTarget(name: "FretboardTests", dependencies: ["Fretboard"]),
        .testTarget(name: "TrainingTests", dependencies: ["Training"]),
        .testTarget(name: "HandCoachTests", dependencies: ["HandCoach"]),
        .testTarget(name: "SongsTests", dependencies: ["Songs"]),
        .testTarget(name: "AICoachTests", dependencies: ["AICoach"]),
        .testTarget(name: "StoryTests", dependencies: ["Story"]),
    ],
    swiftLanguageModes: [.v6]
)
