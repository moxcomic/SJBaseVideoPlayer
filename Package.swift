// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SJBaseVideoPlayer",
    platforms: [.iOS(.v15)],
    products: [.library(name: "SJBaseVideoPlayer", targets: ["SJBaseVideoPlayer"])],
    dependencies: [
        .package(url: "https://github.com/moxcomic/SJUIKit.git", branch: "main"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.0"),
    ],
    targets: [
        .target(
            name: "SJBaseVideoPlayer",
            dependencies: [
                .product(name: "SJUIKit", package: "SJUIKit"),
                .product(name: "SnapKit", package: "SnapKit"),
            ],
            path: "Sources/SJBaseVideoPlayer",
            resources: [.copy("ResourceLoader/SJBaseVideoPlayerResources.bundle")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
