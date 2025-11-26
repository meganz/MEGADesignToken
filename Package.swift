// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MEGADesignToken",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MEGADesignToken",
            targets: ["MEGADesignToken"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "MEGADesignToken",
            path: "Framework/MEGADesignToken/xcframeworks/MEGADesignToken.xcframework"
        ),
        .testTarget(
            name: "MEGADesignTokenTests",
            dependencies: ["MEGADesignToken"]
        )
    ]
)
