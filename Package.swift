// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let bumblebee = Target.Dependency.product(name: "Bumblebee", package: "Bumblebee")
let package = Package(
    name: "SingleRecord",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "SingleRecord", targets: ["SingleRecord"])
    ],
    dependencies: [
        .package(url: "https://github.com/sugarbaron/bumblebee.git", exact: Version("1.0.1"))
    ],
    targets: [
        .target(
            name: "SingleRecord",
            dependencies: [bumblebee],
            path: "Sources")
    ]
)

