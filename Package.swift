// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AsyncLatencyInstrumenter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "async-latency-instrumenter",
            targets: ["CLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        // Main CLI executable
        .executableTarget(
            name: "CLI",
            dependencies: [
                "Core",
                "Reporting"
            ],
            path: "Sources/CLI"
        ),
        
        // Core instrumentation logic
        .target(
            name: "Core",
            dependencies: [
                "Models",
                "Analysis",
                "Rewriting",
                "Reporting",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/Core"
        ),
        
        // Code analysis
        .target(
            name: "Analysis",
            dependencies: [
                "Models",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/Analysis"
        ),
        
        // AST rewriting
        .target(
            name: "Rewriting",
            dependencies: [
                "Models",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/Rewriting"
        ),
        
        // Reporting/output
        .target(
            name: "Reporting",
            dependencies: ["Models"],
            path: "Sources/Reporting"
        ),
        
        // Data models
        .target(
            name: "Models",
            dependencies: [],
            path: "Sources/Models"
        )
    ]
)
