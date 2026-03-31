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

/*
 SQLite store를 실제로 다시 여는 과정에서 migration 정책이 기대한 대로 동작하는지 확인하는 테스트입니다.

 이 테스트는 단순 옵션 값 비교를 넘어서,
 서로 다른 두 버전의 NSManagedObjectModel을 사용해 같은 SQLite store를 순차적으로 열어봅니다.
 이를 통해 configuration에 기록된 migration 정책이
 store 로딩 성공/실패에 실제로 영향을 주는지 검증합니다.
 */
final class CoreDataMigrationTests: XCTestCase {
    /*
     테스트 전용 v1/v2 모델을 생성하는 빌더입니다.

     v1 모델은 SearchHistoryRecord 엔터티에 keyword, lastSearchedAt 속성만 포함합니다.
     v2 모델은 여기에 optional locale 속성을 추가합니다.
     locale 추가는 Core Data가 lightweight migration으로 처리할 수 있는 대표적인 변경 예시입니다.
     */
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

    /*
     테스트가 사용할 임시 SQLite 저장소 URL을 생성합니다.

     각 테스트는 서로 다른 디렉터리를 사용해 store 파일 충돌을 피하고,
     종료 시 디렉터리를 함께 삭제해 sqlite, shm, wal 파일을 한 번에 정리합니다.
     */
    private func makeTemporaryStoreURL() -> (directoryURL: URL, storeURL: URL) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = directoryURL.appendingPathComponent("Migration.sqlite")
        return (directoryURL, storeURL)
    }

    /*
     v1 모델로 생성한 SQLite store를 v2 모델과 lightweight migration 정책으로 다시 열 수 있는지 검증합니다.

     먼저 v1 store에 SearchHistoryRecord 데이터를 저장한 뒤,
     같은 store를 optional locale 속성이 추가된 v2 모델로 reopen합니다.
     migration이 성공하면 기존 데이터는 유지되어야 하고,
     새 속성은 nil 상태로 읽을 수 있어야 합니다.
     */
    func test_make_withLightweightMigration_loadsExistingSQLiteStoreUsingNewModel() async throws {
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

        XCTAssertEqual(fetchedValues.0, "swift")
        XCTAssertNil(fetchedValues.1)
    }

    /*
     migration이 비활성화된 상태에서는 호환되지 않는 SQLite store 로딩이 실패하는지 검증합니다.

     v1 모델로 만들어진 store를 v2 모델로 다시 열 때 automatic migration을 끄면,
     Core Data는 모델 차이를 자동으로 해결하지 않으므로 store 로딩 실패가 발생해야 합니다.
     */
    func test_make_withDisabledMigration_failsToLoadIncompatibleSQLiteStore() async throws {
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
