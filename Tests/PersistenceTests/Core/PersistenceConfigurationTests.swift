//
//  PersistenceConfigurationTests.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
import CoreData
import XCTest
@testable import Persistence

/// PersistenceConfiguration의 기본 설정값과 검증 동작을 확인하는 테스트입니다.
final class PersistenceConfigurationTests: XCTestCase {
    func test_inMemoryConfiguration_whenUsingDefaultFactory_usesInMemoryStore() {
        // given / when
        let configuration = PersistenceConfiguration.inMemory()

        // then
        guard case .inMemory = configuration.storeKind else {
            return XCTFail("Expected in-memory store")
        }
    }

    func test_inMemoryConfiguration_withMigrationPlan_keepsMigrationPlan() {
        // given / when
        let configuration = PersistenceConfiguration.inMemory(
            migrationPlan: .disabled
        )

        // then
        XCTAssertEqual(configuration.migrationPlan, .disabled)
    }

    func test_inMemoryConfiguration_withProgrammaticModel_keepsModelSource() {
        // given / when
        let configuration = PersistenceConfiguration.inMemory(
            modelSource: ProgrammaticPersistenceModel.defaultSource(modelName: "ProgrammaticModel")
        )

        // then
        guard case .programmatic(let modelName, _) = configuration.modelSource else {
            return XCTFail("Expected programmatic model source")
        }

        XCTAssertEqual(modelName, "ProgrammaticModel")
        XCTAssertEqual(configuration.modelName, "ProgrammaticModel")
    }

    func test_liveConfiguration_withDirectoryAndFileName_createsSQLiteURL() throws {
        // given
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }

        // when
        let configuration = try PersistenceConfiguration.live(
            directoryName: "Persistence",
            fileName: "Persistence.sqlite",
            baseDirectoryURL: temporaryDirectoryURL
        )

        // then
        guard case let .sqlite(url) = configuration.storeKind else {
            return XCTFail("Expected sqlite store")
        }

        XCTAssertEqual(url.pathExtension, "sqlite")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "Persistence")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path)
        )
    }

    func test_liveConfiguration_withProgrammaticModel_createsSQLiteURL() throws {
        // given
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }

        // when
        let configuration = try PersistenceConfiguration.live(
            modelSource: ProgrammaticPersistenceModel.defaultSource(),
            directoryName: "Persistence",
            fileName: "Persistence.sqlite",
            baseDirectoryURL: temporaryDirectoryURL
        )

        // then
        guard case let .sqlite(url) = configuration.storeKind else {
            return XCTFail("Expected sqlite store")
        }

        XCTAssertEqual(configuration.modelName, "PersistenceModel")
        XCTAssertEqual(url.pathExtension, "sqlite")
    }

    func test_persistentStoreDescription_withSQLiteStore_appliesMigrationPlan() throws {
        // given
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }

        // when
        let configuration = try PersistenceConfiguration.live(
            directoryName: "Persistence",
            fileName: "Persistence.sqlite",
            baseDirectoryURL: temporaryDirectoryURL,
            migrationPlan: .disabled
        )
        let description = configuration.persistentStoreDescription

        // then
        XCTAssertEqual(description.type, NSSQLiteStoreType)
        XCTAssertFalse(description.shouldMigrateStoreAutomatically)
        XCTAssertFalse(description.shouldInferMappingModelAutomatically)
    }

    func test_persistentStoreDescription_withInMemoryStore_usesInMemoryStoreType() {
        // given / when
        let configuration = PersistenceConfiguration.inMemory(
            migrationPlan: .disabled
        )
        let description = configuration.persistentStoreDescription

        // then
        XCTAssertEqual(description.type, NSInMemoryStoreType)
    }

    func test_liveConfiguration_withEmptyDirectoryName_throwsInvalidConfiguration() {
        // when / then
        XCTAssertThrowsError(
            try PersistenceConfiguration.live(directoryName: " ")
        ) { error in
            guard case let PersistenceError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withInvalidMigrationPlan_throwsInvalidConfiguration() {
        // given
        let configuration = PersistenceConfiguration.inMemory(
            migrationPlan: PersistenceMigrationPlan(
                shouldMigrateStoreAutomatically: false,
                shouldInferMappingModelAutomatically: true
            )
        )

        // when / then
        XCTAssertThrowsError(try configuration.validate()) { error in
            guard case let PersistenceError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }
}
