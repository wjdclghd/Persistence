// swift-tools-version: 5.9
//
//  Package.swift
//  Persistence
//
//  Created by jch on 3/21/26.
//

import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Persistence",
            targets: ["Persistence"]
        )
    ],
    dependencies: [
//        .package(url: "https://github.com/realm/realm-swift.git", from: "20.0.4")
    ],
    targets: [
        .target(
            name: "Persistence",
            dependencies: [
//                .product(name: "RealmSwift", package: "realm-swift")
            ],
            path: "Sources/Persistence"
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                "Persistence",
//                .product(name: "RealmSwift", package: "realm-swift")
            ],
            path: "Tests/PersistenceTests"
        )
    ]
)
