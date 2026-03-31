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
                
            ],
            path: "Tests/PersistenceTests"
        )
    ]
)
