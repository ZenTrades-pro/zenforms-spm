// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "ZenForms",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ZenForms",
            targets: ["ZenForms"]
        )
    ],
    dependencies: [
        // MARK: - Drawing / UI
        .package(url: "https://github.com/vishalrana-zt/ACEDrawingView.git", branch: "master"),
        .package(url: "https://github.com/airbnb/lottie-ios.git", .upToNextMajor(from: "4.5.1")),
        .package(url: "https://github.com/jdg/MBProgressHUD.git", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/ElaWorkshop/TagListView.git", exact: "1.4.1"),
        .package(url: "https://github.com/harshirzentrades/Zen-UIView-Shimmer.git", .upToNextMajor(from: "1.0.0")),

        // MARK: - Networking & Observability
        .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.6.0"),
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", .upToNextMajor(from: "3.0.0")),
        
        // MARK: - Database
        .package(url: "https://github.com/groue/GRDB.swift", branch: "master"),

        // MARK: - Keyboard Management
        .package(url: "https://github.com/hackiftekhar/IQKeyboardManager.git", branch: "master"),

        // MARK: - Utilities
        .package(url: "https://github.com/ashleymills/Reachability.swift", branch: "master"),
        .package(url: "https://github.com/globulus/swiftui-flow-layout", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/onevcat/Kingfisher", .upToNextMajor(from: "8.8.1")),

        // MARK: - Internal Libraries
        .package(url: "https://github.com/vishalrana-zt/PPSSignatureView.git", branch: "master"),
        .package(url: "https://github.com/vishalrana-zt/RSSelectionMenu.git", branch: "master"),
        .package(url: "https://github.com/vishalrana-zt/SSMediaManager", branch: "main"),
        .package(url: "https://github.com/vishalrana-zt/ZTExpressionEngine", branch: "main")
    ],
    targets: [
        .target(
            name: "ZenForms",
            dependencies: [
                "ACEDrawingView",
                "Alamofire",
                .product(name: "DatadogCore", package: "dd-sdk-ios"),
                .product(name: "DatadogLogs", package: "dd-sdk-ios"),
                .product(name: "DatadogCrashReporting", package: "dd-sdk-ios"),
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "MBProgressHUD", package: "MBProgressHUD"),
                .product(name: "TagListView", package: "TagListView"),
                .product(name: "UIView-Shimmer", package: "Zen-UIView-Shimmer"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "IQKeyboardManagerSwift", package: "IQKeyboardManager"),
                .product(name: "Reachability", package: "Reachability.swift"),
                .product(name: "SwiftUIFlowLayout", package: "swiftui-flow-layout"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "PPSSignatureView", package: "PPSSignatureView"),
                .product(name: "RSSelectionMenu", package: "RSSelectionMenu"),
                .product(name: "SSMediaManager", package: "SSMediaManager"),
                .product(name: "ZTExpressionEngine", package: "ZTExpressionEngine")
            ],
            resources: [
                .process("Resources/JSON"),
                .process("Resources/XIB"),
                .process("Resources/Assets.xcassets"),
                .process("Resources/StringsFiles")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
