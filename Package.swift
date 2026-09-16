// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "GrammarLlama",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GrammarLlama",
            path: "Sources/GrammarLlama",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
