// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "C_LLVM",
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "C_LLVM",
			targets: ["C_LLVM"]
		),
	],
	targets: [
		.systemLibrary(
			name: "C_LLVM",
			pkgConfig: "cllvm",
			providers: [
				.brew(["llvm"])
			]
		),
		.testTarget(
			name: "C_LLVMTests",
			dependencies: ["C_LLVM"]
		),
	],
	cxxLanguageStandard: .cxx20
)
