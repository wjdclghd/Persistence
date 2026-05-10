// swift-tools-version: 6.0
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
        
    ],
    targets: [
        .target(
            name: "Persistence",
            dependencies: [
                
            ],
            path: "Sources/Persistence",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PersistenceTests",
            dependencies: [
                "Persistence"
            ],
            path: "Tests/PersistenceTests"
        )
    ],
    swiftLanguageModes: [
        .v6
    ]
)
