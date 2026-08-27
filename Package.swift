// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "swift-clocks",
  // NB: While the `Clock` protocol is iOS 16+, etc., the package should support earlier platforms
  //     so that depending libraries and applications can conditionally use the library via
  //     availability checks.
  platforms: [
    .iOS(.v15),
    .macOS(.v12),
    .tvOS(.v15),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "Clocks",
      targets: ["Clocks"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-issue-reporting", from: "2.1.0"),
  ],
  targets: [
    .target(
      name: "Clocks",
      dependencies: [
        .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
        .product(name: "IssueReporting", package: "swift-issue-reporting"),
      ]
    ),
    .testTarget(
      name: "ClocksTests",
      dependencies: [
        "Clocks"
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)

for target in package.targets {
  target.swiftSettings = target.swiftSettings ?? []
  target.swiftSettings?.append(contentsOf: [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  ])
}
