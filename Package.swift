// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LLVM",
		platforms: [.macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "C_LLVM",
            targets: ["C_LLVM"]
        ),
        .library(
            name: "LLVM",
            targets: ["LLVM"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing", branch: "main"),
    ],
    targets: [
        .systemLibrary(
            name: "C_LLVM",
            pkgConfig: "cllvm",
            providers: [
                .brew(["llvm"]),
            ]
        ),
        .target(
            name: "LLVM",
            dependencies: ["C_LLVM"]
        ),
        .testTarget(
            name: "C_LLVMTests",
            dependencies: ["C_LLVM"]
        ),
    ]
)
