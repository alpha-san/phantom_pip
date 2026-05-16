// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PhantomPiP",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PhantomPiP",
            path: "Sources/PhantomPiP"
        )
    ]
)
