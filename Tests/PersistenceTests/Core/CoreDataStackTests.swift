//
//  CoreDataStackTests.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
import CoreData
import XCTest
@testable import Persistence

/// CoreDataStack의 생성, 저장소 접근, 에러 매핑 동작을 검증하는 테스트입니다.
final class CoreDataStackTests: XCTestCase {
    /// 테스트에서 발생시키는 의도적인 실패를 표현하는 에러 타입입니다.
    private enum TestFailure: Error {
        case expected
    }

    /// 모델 로딩 실패를 검증할 때 사용할 테스트 번들 토큰입니다.
    private final class TestBundleToken {}

    /// 엔티티 이름이 없는 programmatic 모델을 만들기 위한 테스트 빌더입니다.
    private enum InvalidProgrammaticModelBuilder {
        static func makeUnnamedEntityModel() -> NSManagedObjectModel {
            let model = NSManagedObjectModel()
            let entity = NSEntityDescription()
            entity.name = " "
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
            model.entities = [entity]
            return model
        }
    }
    func test_make_inMemoryStack_succeeds() async throws {
        // given / when
        let stack = try await InMemoryCoreDataStack.make()
        // then
        XCTAssertNotNil(stack.viewContext)
    }

    func test_make_inMemoryStack_withProgrammaticModel_succeeds() async throws {
        // given / when
        let stack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        // then
        XCTAssertNotNil(stack.viewContext)
    }

    func test_performWrite_and_performRead_persistsAndFetchesSearchHistory() async throws {
        // given / when
        let stack = try await InMemoryCoreDataStack.make()
        let fetchedValues = try await persistAndFetchSearchHistory(
            using: stack,
            keyword: "swiftui",
            lastSearchedAt: Date(timeIntervalSince1970: 1_711_644_800)
        )
        // then
        XCTAssertEqual(fetchedValues.0, "swiftui")
        XCTAssertEqual(fetchedValues.1, Date(timeIntervalSince1970: 1_711_644_800))
    }

    func test_performWrite_and_performRead_withProgrammaticModel_persistsAndFetchesSearchHistory() async throws {
        // given / when
        let stack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        let fetchedValues = try await persistAndFetchSearchHistory(
            using: stack,
            keyword: "combine",
            lastSearchedAt: Date(timeIntervalSince1970: 1_711_731_200)
        )
        // then
        XCTAssertEqual(fetchedValues.0, "combine")
        XCTAssertEqual(fetchedValues.1, Date(timeIntervalSince1970: 1_711_731_200))
    }

    func test_performRead_whenBlockThrows_mapsToReadFailed() async throws {
        // given
        let stack = try await InMemoryCoreDataStack.make()

        // when / then
        do {
            _ = try await stack.performRead { _ in
                throw TestFailure.expected
            }
            XCTFail("Expected readFailed error")
        } catch let error as PersistenceError {
            guard case let .readFailed(message) = error else {
                return XCTFail("Expected readFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_performWrite_whenBlockThrows_mapsToWriteFailed() async throws {
        // given
        let stack = try await InMemoryCoreDataStack.make()

        // when / then
        do {
            _ = try await stack.performWrite { _ in
                throw TestFailure.expected
            }
            XCTFail("Expected writeFailed error")
        } catch let error as PersistenceError {
            guard case let .writeFailed(message) = error else {
                return XCTFail("Expected writeFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_make_withEmptyModelName_throwsInvalidConfiguration() async {
        // given
        let configuration = PersistenceConfiguration(
            modelName: "  ",
            modelBundle: .module,
            storeKind: .inMemory
        )

        // when / then
        do {
            _ = try await CoreDataStack.make(configuration: configuration)
            XCTFail("Expected invalidConfiguration error")
        } catch let error as PersistenceError {
            guard case let .invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_make_withUnknownModelInDifferentBundle_throwsModelNotFound() async {
        // given
        let configuration = PersistenceConfiguration.inMemory(
            modelName: "UnknownModel",
            modelBundle: Bundle(for: TestBundleToken.self)
        )

        // when / then
        do {
            _ = try await CoreDataStack.make(configuration: configuration)
            XCTFail("Expected modelNotFound error")
        } catch let error as PersistenceError {
            guard case let .modelNotFound(modelName, bundlePath) = error else {
                return XCTFail("Expected modelNotFound, got \(error)")
            }

            XCTAssertEqual(modelName, "UnknownModel")
            XCTAssertFalse(bundlePath.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_make_withInvalidProgrammaticModel_throwsInvalidConfiguration() async {
        // given
        let configuration = PersistenceConfiguration.inMemory(
            modelSource: .programmatic(
                modelName: "PersistenceModel",
                makeManagedObjectModel: {
                    InvalidProgrammaticModelBuilder.makeUnnamedEntityModel()
                }
            )
        )

        // when / then
        do {
            _ = try await CoreDataStack.make(configuration: configuration)
            XCTFail("Expected invalidConfiguration error")
        } catch let error as PersistenceError {
            guard case let .invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private extension CoreDataStackTests {
    func persistAndFetchSearchHistory(
        using stack: any CoreDataStackProtocol,
        keyword: String,
        lastSearchedAt: Date
    ) async throws -> (String, Date) {
        try await stack.performWrite { context in
            let object = NSEntityDescription.insertNewObject(
                forEntityName: "SearchHistoryRecord",
                into: context
            )
            object.setValue(keyword, forKey: "keyword")
            object.setValue(lastSearchedAt, forKey: "lastSearchedAt")
        }

        return try await stack.performRead { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "SearchHistoryRecord")
            request.fetchLimit = 1
            let objects = try context.fetch(request)
            let object = try XCTUnwrap(objects.first)
            let fetchedKeyword = try XCTUnwrap(object.value(forKey: "keyword") as? String)
            let fetchedDate = try XCTUnwrap(object.value(forKey: "lastSearchedAt") as? Date)
            return (fetchedKeyword, fetchedDate)
        }
    }
}
