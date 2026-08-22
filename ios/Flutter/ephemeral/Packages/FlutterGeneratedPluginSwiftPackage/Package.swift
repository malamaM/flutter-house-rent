// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "audioplayers_darwin", path: "../.packages/audioplayers_darwin-6.4.0"),
        .package(name: "file_picker", path: "../.packages/file_picker-8.3.7"),
        .package(name: "geolocator_apple", path: "../.packages/geolocator_apple-2.3.13"),
        .package(name: "image_picker_ios", path: "../.packages/image_picker_ios-0.8.12+2"),
        .package(name: "path_provider_foundation", path: "../.packages/path_provider_foundation-2.4.1"),
        .package(name: "share_plus", path: "../.packages/share_plus-10.1.4"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.4"),
        .package(name: "sqflite_darwin", path: "../.packages/sqflite_darwin-2.4.2"),
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.3.4"),
        .package(name: "video_player_avfoundation", path: "../.packages/video_player_avfoundation-2.8.4"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "audioplayers-darwin", package: "audioplayers_darwin"),
                .product(name: "file-picker", package: "file_picker"),
                .product(name: "geolocator-apple", package: "geolocator_apple"),
                .product(name: "image-picker-ios", package: "image_picker_ios"),
                .product(name: "path-provider-foundation", package: "path_provider_foundation"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "sqflite-darwin", package: "sqflite_darwin"),
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "video-player-avfoundation", package: "video_player_avfoundation"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
