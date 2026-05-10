//
//  CoreDataMigrationTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData
import XCTest
@testable import Persistence

/// SQLite store를 실제로 다시 여는 과정에서 migration 정책이 기대한 대로 동작하는지 확인하는 테스트입니다.
final class CoreDataMigrationTests: XCTestCase {
    private enum MigrationTestModelBuilder {
        static func makeVersion1() -> NSManagedObjectModel {
            let model = NSManagedObjectModel()
            model.versionIdentifiers = ["v1"]
            model.entities = [makeSearchHistoryEntity(includeLocale: false)]
            return model
        }

        static func makeVersion2() -> NSManagedObjectModel {
            let model = NSManagedObjectModel()
            model.versionIdentifiers = ["v2"]
            model.entities = [makeSearchHistoryEntity(includeLocale: true)]
            return model
        }

        private static func makeSearchHistoryEntity(includeLocale: Bool) -> NSEntityDescription {
            let entity = NSEntityDescription()
            entity.name = "SearchHistoryRecord"
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

            let keyword = NSAttributeDescription()
            keyword.name = "keyword"
            keyword.attributeType = .stringAttributeType
            keyword.isOptional = false

            let lastSearchedAt = NSAttributeDescription()
            lastSearchedAt.name = "lastSearchedAt"
            lastSearchedAt.attributeType = .dateAttributeType
            lastSearchedAt.isOptional = false

            var properties: [NSPropertyDescription] = [keyword, lastSearchedAt]

            if includeLocale {
                let locale = NSAttributeDescription()
                locale.name = "locale"
                locale.attributeType = .stringAttributeType
                locale.isOptional = true
                properties.append(locale)
            }

            entity.properties = properties
            entity.uniquenessConstraints = [["keyword"]]
            return entity
        }
    }

    private func makeTemporaryStoreURL() -> (directoryURL: URL, storeURL: URL) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Migration.sqlite")
        return (directoryURL, storeURL)
    }

    func test_make_withLightweightMigration_loadsExistingSQLiteStoreUsingNewModel() async throws {
        // given
        let paths = makeTemporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: paths.directoryURL)
        }

        try FileManager.default.createDirectory(
            at: paths.directoryURL,
            withIntermediateDirectories: true
        )

        let version1Configuration = PersistenceConfiguration(
            modelSource: .programmatic(
                modelName: "MigrationModel",
                makeManagedObjectModel: {
                    MigrationTestModelBuilder.makeVersion1()
                }
            ),
            storeKind: .sqlite(url: paths.storeURL),
            migrationPlan: .lightweight
        )

        let version1Stack = try await CoreDataStack.make(configuration: version1Configuration)

        _ = try await version1Stack.performWrite { context in
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: "SearchHistoryRecord",
                into: context
            )
            entity.setValue("swift", forKey: "keyword")
            entity.setValue(Date(timeIntervalSince1970: 1_711_644_800), forKey: "lastSearchedAt")
            return ()
        }

        let version2Configuration = PersistenceConfiguration(
            modelSource: .programmatic(
                modelName: "MigrationModel",
                makeManagedObjectModel: {
                    MigrationTestModelBuilder.makeVersion2()
                }
            ),
            storeKind: .sqlite(url: paths.storeURL),
            migrationPlan: .lightweight
        )

        // when
        let version2Stack = try await CoreDataStack.make(configuration: version2Configuration)

        let fetchedValues = try await version2Stack.performRead { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "SearchHistoryRecord")
            request.fetchLimit = 1

            guard let object = try context.fetch(request).first else {
                throw NSError(domain: "CoreDataMigrationTests", code: 0)
            }
            let keyword = object.value(forKey: "keyword") as? String
            let locale = object.value(forKey: "locale") as? String
            return (keyword, locale)
        }

        // then
        XCTAssertEqual(fetchedValues.0, "swift")
        XCTAssertNil(fetchedValues.1)
    }

    func test_make_withDisabledMigration_failsToLoadIncompatibleSQLiteStore() async throws {
        // given
        let paths = makeTemporaryStoreURL()
        defer {
            try? FileManager.default.removeItem(at: paths.directoryURL)
        }

        try FileManager.default.createDirectory(
            at: paths.directoryURL,
            withIntermediateDirectories: true
        )

        let version1Configuration = PersistenceConfiguration(
            modelSource: .programmatic(
                modelName: "MigrationModel",
                makeManagedObjectModel: {
                    MigrationTestModelBuilder.makeVersion1()
                }
            ),
            storeKind: .sqlite(url: paths.storeURL),
            migrationPlan: .lightweight
        )

        let version1Stack = try await CoreDataStack.make(configuration: version1Configuration)

        _ = try await version1Stack.performWrite { context in
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: "SearchHistoryRecord",
                into: context
            )
            entity.setValue("combine", forKey: "keyword")
            entity.setValue(Date(timeIntervalSince1970: 1_711_731_200), forKey: "lastSearchedAt")
            return ()
        }

        let version2Configuration = PersistenceConfiguration(
            modelSource: .programmatic(
                modelName: "MigrationModel",
                makeManagedObjectModel: {
                    MigrationTestModelBuilder.makeVersion2()
                }
            ),
            storeKind: .sqlite(url: paths.storeURL),
            migrationPlan: .disabled
        )

        // when / then
        do {
            _ = try await CoreDataStack.make(configuration: version2Configuration)
            XCTFail("Expected persistentStoreLoadFailed error")
        } catch let error as PersistenceError {
            guard case let .persistentStoreLoadFailed(message) = error else {
                return XCTFail("Expected persistentStoreLoadFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
