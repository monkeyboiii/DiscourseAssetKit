// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DiscourseAssetKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "DiscourseAssetKit",
            targets: ["DiscourseAssetKit"]
        ),
    ],
    targets: [
        .target(
            name: "DiscourseAssetKit",
            resources: [
                .copy("Resources/Emojis"),
                .process("Resources/DiscourseIcons.xcassets"),
            ]
        ),
        .testTarget(
            name: "DiscourseAssetKitTests",
            dependencies: ["DiscourseAssetKit"]
        ),
    ]
)
