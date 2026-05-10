//
//  FavoriteStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/// FavoriteStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.
final class FavoriteStoreTests: XCTestCase {
    func test_fetchAll_returnsRecordsSortedByCreatedAtDescending() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            FavoriteRecord(
                id: "100",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await store.save(
            FavoriteRecord(
                id: "200",
                type: "movie",
                createdAt: Date(timeIntervalSince1970: 300)
            )
        )
        try await store.save(
            FavoriteRecord(
                id: "300",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )

        // when
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.map(\.id), ["200", "300", "100"])
    }

    func test_save_withExistingCompositeKey_updatesExistingRecord() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            FavoriteRecord(
                id: "100",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )

        // when
        try await store.save(
            FavoriteRecord(
                id: "100",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 500)
            )
        )
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, "100")
        XCTAssertEqual(records.first?.type, "app")
        XCTAssertEqual(records.first?.createdAt, Date(timeIntervalSince1970: 500))
    }

    func test_save_withDifferentType_keepsSeparateRecords() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            FavoriteRecord(
                id: "100",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )

        // when
        try await store.save(
            FavoriteRecord(
                id: "100",
                type: "movie",
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.map(\.type), ["movie", "app"])
    }

    func test_fetchRecords_ofType_returnsFilteredResults() async throws {
        // given
        let store = try await makeStore()
        try await seedRecords(on: store)

        // when
        let records = try await store.fetchRecords(ofType: "app")

        // then
        XCTAssertEqual(records.map(\.id), ["300", "100"])
        XCTAssertTrue(records.allSatisfy { $0.type == "app" })
    }

    func test_fetchRecord_returnsMatchingRecord() async throws {
        // given
        let store = try await makeStore()
        try await seedRecords(on: store)

        // when
        let record = try await store.fetchRecord(id: "200", type: "movie")

        // then
        XCTAssertEqual(record?.id, "200")
        XCTAssertEqual(record?.type, "movie")
        XCTAssertEqual(record?.createdAt, Date(timeIntervalSince1970: 300))
    }

    func test_delete_removesOnlyMatchingRecord() async throws {
        // given
        let store = try await makeStore()
        try await seedRecords(on: store)

        // when
        try await store.delete(id: "200", type: "movie")
        let records = try await store.fetchAll()
        let deletedRecord = try await store.fetchRecord(id: "200", type: "movie")

        // then
        XCTAssertEqual(records.count, 2)
        XCTAssertNil(deletedRecord)
    }

    func test_deleteAll_removesAllRecords() async throws {
        // given
        let store = try await makeStore()
        try await seedRecords(on: store)

        // when
        try await store.deleteAll()
        let records = try await store.fetchAll()

        // then
        XCTAssertTrue(records.isEmpty)
    }

    func test_save_withBlankID_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()

        // when / then
        do {
            try await store.save(
                FavoriteRecord(
                    id: "   ",
                    type: "app",
                    createdAt: Date()
                )
            )
            XCTFail("Expected writeFailed error")
        } catch let error as PersistenceError {
            guard case let .writeFailed(message) = error else {
                return XCTFail("Expected writeFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_save_withBlankType_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()

        // when / then
        do {
            try await store.save(
                FavoriteRecord(
                    id: "100",
                    type: "   ",
                    createdAt: Date()
                )
            )
            XCTFail("Expected writeFailed error")
        } catch let error as PersistenceError {
            guard case let .writeFailed(message) = error else {
                return XCTFail("Expected writeFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_makeFavoriteStore_fromContainer_succeeds() async throws {
        // given
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeFavoriteStore()

        // when
        try await store.save(
            FavoriteRecord(
                id: "999",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 700)
            )
        )
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, "999")
        XCTAssertEqual(records.first?.type, "app")
    }
}

private extension FavoriteStoreTests {
    /// 테스트용 Favorite store를 생성합니다.
    ///
    /// - Returns:
    /// - in-memory Core Data stack 위에 구성된 FavoriteStore 구현체
    ///
    /// - Throws:
    /// - Core Data stack 초기화에 실패하면 에러를 던집니다.
    func makeStore() async throws -> any FavoriteStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataFavoriteStore(coreDataStack: coreDataStack)
    }

    /// 즐겨찾기 테스트 데이터 3건을 저장합니다.
    ///
    /// - Parameters:
    ///   - store: 테스트 데이터를 저장할 즐겨찾기 store
    ///
    /// - Throws:
    /// - 저장 과정에서 오류가 발생하면 에러를 던집니다.
    func seedRecords(
        on store: any FavoriteStoreProtocol
    ) async throws {
        try await store.save(
            FavoriteRecord(
                id: "100",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await store.save(
            FavoriteRecord(
                id: "200",
                type: "movie",
                createdAt: Date(timeIntervalSince1970: 300)
            )
        )
        try await store.save(
            FavoriteRecord(
                id: "300",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )
    }
}
