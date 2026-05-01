// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yandex_login_sdk",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "yandex-login-sdk", targets: ["yandex_login_sdk"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/yandexmobile/yandex-login-sdk-ios.git",
            from: "3.1.0"
        ),
    ],
    targets: [
        .target(
            name: "yandex_login_sdk",
            dependencies: [
                .product(name: "YandexLoginSDK", package: "yandex-login-sdk-ios"),
            ],
            resources: []
        ),
    ]
)
