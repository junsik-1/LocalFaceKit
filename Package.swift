// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LocalFaceKit",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(name: "LocalFaceKit", targets: ["LocalFaceKit"])
  ],
  targets: [
    .target(
      name: "LocalFaceKit",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "LocalFaceKitTests",
      dependencies: ["LocalFaceKit"]
    ),
  ]
)
