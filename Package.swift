// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapacitorChildwindow",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "CapacitorChildwindow",
            targets: ["ChildWindowPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "ChildWindowPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/ChildWindowPlugin"),
        .testTarget(
            name: "ChildWindowPluginTests",
            dependencies: ["ChildWindowPlugin"],
            path: "ios/Tests/ChildWindowPluginTests")
    ]
)