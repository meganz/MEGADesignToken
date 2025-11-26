// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TokenCodegen",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .plugin(
            name: "TokenCodegen",
            targets: ["TokenCodegen"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", exact: "509.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .plugin(
            name: "TokenCodegen",
            capability: .buildTool(),
            dependencies: ["TokenCodegenGenerator"],
        ),
        .executableTarget(
            name: "TokenCodegenGenerator",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax")
            ]
        ),
        .testTarget(
            name: "TokenCodegenGeneratorTests",
            dependencies: ["TokenCodegenGenerator"]
        )
    ]
)
