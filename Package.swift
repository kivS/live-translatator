// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RegionTranslate",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "RegionTranslate", targets: ["RegionTranslate"])],
    targets: [.executableTarget(name: "RegionTranslate"),
              .testTarget(name: "RegionTranslateTests", dependencies: ["RegionTranslate"])],
    swiftLanguageModes: [.v5]
)
