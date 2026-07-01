// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TerrariumLog",
    platforms: [.iOS(.v17)],
    products: [
        .executable(
            name: "TerrariumLog",
            targets: ["TerrariumLog"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TerrariumLog",
            path: "TerrariumLog",
            exclude: ["TerrariumLog.xcodeproj", "README.md"]
        )
    ]
)
