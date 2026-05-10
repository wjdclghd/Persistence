//
//  SyncStateStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/// SyncStateStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.
final class SyncStateStoreTests: XCTestCase {
    func test_fetchAll_returnsRecordsSortedByNamespaceAscending() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: "cursor-300",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 300)
            )
        )
        try await store.save(
            SyncStateRecord(
                namespace: "dev",
                cursor: nil,
                isDirty: false,
                lastSyncedAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await store.save(
            SyncStateRecord(
                namespace: "stage",
                cursor: "cursor-200",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 200)
            )
        )

        // when
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.map(\.namespace), ["dev", "prod", "stage"])
    }

    func test_save_withExistingNamespace_updatesExistingRecord() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: nil,
                isDirty: false,
                lastSyncedAt: Date(timeIntervalSince1970: 100)
            )
        )

        // when
        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: "cursor-500",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 500)
            )
        )
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.namespace, "prod")
        XCTAssertEqual(records.first?.cursor, "cursor-500")
        XCTAssertEqual(records.first?.isDirty, true)
        XCTAssertEqual(records.first?.lastSyncedAt, Date(timeIntervalSince1970: 500))
    }

    func test_fetchRecord_returnsMatchingRecord() async throws {
        // given
        let store = try await makeStore()
        try await seedRecords(on: store)

        // when
        let record = try await store.fetchRecord(for: "stage")

        // then
        XCTAssertEqual(record?.namespace, "stage")
        XCTAssertEqual(record?.cursor, "cursor-stage")
        XCTAssertEqual(record?.isDirty, true)
        XCTAssertEqual(record?.lastSyncedAt, Date(timeIntervalSince1970: 200))
    }

    func test_save_withBlankNamespace_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()

        // when / then
        do {
            try await store.save(
                SyncStateRecord(
                    namespace: "   ",
                    cursor: "cursor",
                    isDirty: false,
                    lastSyncedAt: Date()
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

    func test_save_withBlankCursor_normalizesToNil() async throws {
        // given
        let store = try await makeStore()

        // when
        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: "   ",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 300)
            )
        )
        let record = try await store.fetchRecord(for: "prod")

        // then
        XCTAssertEqual(record?.namespace, "prod")
        XCTAssertNil(record?.cursor)
    }

    func test_delete_removesOnlyMatchingRecord() async throws {
        // given
        let store = try await makeStore()
        try await seedRecords(on: store)

        // when
        try await store.delete(namespace: "stage")
        let records = try await store.fetchAll()
        let deletedRecord = try await store.fetchRecord(for: "stage")

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

    func test_makeSyncStateStore_fromContainer_succeeds() async throws {
        // given
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeSyncStateStore()

        // when
        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: "cursor-prod",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 700)
            )
        )
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.namespace, "prod")
        XCTAssertEqual(records.first?.cursor, "cursor-prod")
    }
}

private extension SyncStateStoreTests {
    /// 테스트용 SyncState store를 생성합니다.
    ///
    /// - Returns:
    /// - in-memory Core Data stack 위에 구성된 SyncStateStore 구현체
    ///
    /// - Throws:
    /// - Core Data stack 초기화에 실패하면 에러를 던집니다.
    func makeStore() async throws -> any SyncStateStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataSyncStateStore(coreDataStack: coreDataStack)
    }

    /// 동기화 상태 테스트 데이터 3건을 저장합니다.
    ///
    /// - Parameters:
    ///   - store: 테스트 데이터를 저장할 동기화 상태 store
    ///
    /// - Throws:
    /// - 저장 과정에서 오류가 발생하면 에러를 던집니다.
    func seedRecords(
        on store: any SyncStateStoreProtocol
    ) async throws {
        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: "cursor-prod",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 300)
            )
        )
        try await store.save(
            SyncStateRecord(
                namespace: "dev",
                cursor: nil,
                isDirty: false,
                lastSyncedAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await store.save(
            SyncStateRecord(
                namespace: "stage",
                cursor: "cursor-stage",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 200)
            )
        )
    }
}
