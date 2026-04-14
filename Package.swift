// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ginko",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0"),
        .package(url: "https://github.com/ileitch/swift-filename-matcher.git", from: "2.0.1")
    ],
    targets: [
        .executableTarget(
            name: "ginko",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "GRDBSQLite", package: "GRDB.swift"),
                .product(name: "FilenameMatcher", package: "swift-filename-matcher")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "ginkoTests",
            dependencies: [
                .target(name: "ginko"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
