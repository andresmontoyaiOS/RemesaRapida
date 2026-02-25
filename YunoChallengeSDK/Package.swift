// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YunoChallengeSDK",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "YunoChallengeSDK", targets: ["YunoChallengeSDK"])
    ],
    targets: [
        .target(
            name: "YunoChallengeSDK",
            path: "Sources/YunoChallengeSDK",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
