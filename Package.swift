// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Arboreal",
    platforms: [.iOS(.v18)],
    products: [
        .library(
            name: "Arboreal",
            targets: ["Arboreal"]
        ),
    ],
    targets: [
        .target(
            name: "Arboreal"
        ),
        .testTarget(
            name: "ArborealTests",
            dependencies: ["Arboreal"]
        ),
    ]
)
