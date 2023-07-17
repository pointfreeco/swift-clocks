// swift-tools-version: 5.6

import PackageDescription

let package = Package(
  name: "swift-clocks",
  // NB: While the `Clock` protocol is iOS 16+, etc., the package should support earlier platforms so that
  //     depending libraries and applications can conditionally use the library via availability checks.
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(
      name: "Clocks",
      targets: ["Clocks"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-async-algorithms", revision: "cf70e78"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "0.1.0"),
    .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "0.8.0"),
  ],
  targets: [
    .target(
      name: "Clocks",
      dependencies: [
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
        .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
      ]
    ),
    .testTarget(
      name: "ClocksTests",
      dependencies: [
        "Clocks",
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
      ]
    ),
  ]
)

//for target in package.targets {
//  target.swiftSettings = target.swiftSettings ?? []
//  target.swiftSettings?.append(
//    .unsafeFlags([
//      "-Xfrontend", "-warn-concurrency",
//      "-Xfrontend", "-enable-actor-data-race-checks",
//      "-enable-library-evolution",
//    ])
//  )
//}
