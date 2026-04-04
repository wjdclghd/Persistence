//
//  SyncStateStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/*
 SyncStateStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.

 이 테스트는 in-memory Core Data 환경에서 동기화 상태 store가
 namespace 기준 upsert,
 정렬 규칙,
 단건 조회,
 개별 삭제와 전체 삭제를 올바르게 수행하는지 확인합니다.
 또한 PersistenceContainer 조립 지점에서 동기화 상태 store를 생성해도
 동일한 동작을 제공하는지 함께 검증합니다.
 */
final class SyncStateStoreTests: XCTestCase {
    /*
     전체 조회 시 namespace 오름차순으로 정렬되는지 검증합니다.

     namespace별 동기화 상태를 안정적으로 표시하기 위해,
     저장 순서와 무관하게 정렬 규칙이 유지되는지 확인합니다.
     */
    func test_fetchAll_returnsRecordsSortedByNamespaceAscending() async throws {
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

        let records = try await store.fetchAll()

        XCTAssertEqual(records.map(\.namespace), ["dev", "prod", "stage"])
    }

    /*
     동일 namespace를 다시 저장하면 중복이 생기지 않고 기존 상태가 갱신되는지 검증합니다.

     동기화 상태는 namespace를 기준으로 uniqueness를 유지해야 하므로,
     같은 namespace를 다시 저장할 때 새 레코드를 추가하지 않고 값만 갱신해야 합니다.
     */
    func test_save_withExistingNamespace_updatesExistingRecord() async throws {
        let store = try await makeStore()

        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: nil,
                isDirty: false,
                lastSyncedAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: "cursor-500",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 500)
            )
        )

        let records = try await store.fetchAll()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.namespace, "prod")
        XCTAssertEqual(records.first?.cursor, "cursor-500")
        XCTAssertEqual(records.first?.isDirty, true)
        XCTAssertEqual(records.first?.lastSyncedAt, Date(timeIntervalSince1970: 500))
    }

    /*
     지정한 namespace의 동기화 상태를 조회할 수 있는지 검증합니다.

     다음 동기화 시점에 마지막 커서와 dirty 여부를 복원할 수 있어야 하므로,
     정확한 상태가 반환되는지 확인합니다.
     */
    func test_fetchRecord_returnsMatchingRecord() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)

        let record = try await store.fetchRecord(for: "stage")

        XCTAssertEqual(record?.namespace, "stage")
        XCTAssertEqual(record?.cursor, "cursor-stage")
        XCTAssertEqual(record?.isDirty, true)
        XCTAssertEqual(record?.lastSyncedAt, Date(timeIntervalSince1970: 200))
    }

    /*
     공백 namespace 저장 시 writeFailed가 발생하는지 검증합니다.

     의미 없는 namespace가 저장소에 남지 않도록,
     저장 시점에 최소한의 입력값 검증이 수행되는지 확인합니다.
     */
    func test_save_withBlankNamespace_throwsWriteFailed() async throws {
        let store = try await makeStore()

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

    /*
     공백 cursor가 nil로 정규화되는지 검증합니다.

     동기화 상태는 공백 문자열 대신 nil로 커서를 보관해야 하므로,
     저장 후 조회 결과가 nil인지 확인합니다.
     */
    func test_save_withBlankCursor_normalizesToNil() async throws {
        let store = try await makeStore()

        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: "   ",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 300)
            )
        )

        let record = try await store.fetchRecord(for: "prod")

        XCTAssertEqual(record?.namespace, "prod")
        XCTAssertNil(record?.cursor)
    }

    /*
     특정 namespace를 삭제하면 해당 상태만 제거되는지 검증합니다.

     namespace별 동기화 초기화 기능에서 정확한 상태만 제거되어야 하므로,
     나머지 상태는 유지되는지 함께 확인합니다.
     */
    func test_delete_removesOnlyMatchingRecord() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)
        try await store.delete(namespace: "stage")

        let records = try await store.fetchAll()
        let deletedRecord = try await store.fetchRecord(for: "stage")

        XCTAssertEqual(records.count, 2)
        XCTAssertNil(deletedRecord)
    }

    /*
     전체 삭제가 모든 동기화 상태를 제거하는지 검증합니다.

     동기화 상태 전체 초기화 기능을 지원하기 위해,
     저장된 상태가 남지 않는지 확인합니다.
     */
    func test_deleteAll_removesAllRecords() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)
        try await store.deleteAll()

        let records = try await store.fetchAll()

        XCTAssertTrue(records.isEmpty)
    }

    /*
     PersistenceContainer가 조립한 동기화 상태 store도 정상 동작하는지 검증합니다.

     상위 계층은 CoreDataSyncStateStore 구체 타입 대신
     컨테이너 조립 지점을 통해 store를 받게 되므로,
     실제 조립 결과가 올바른 계약 구현체인지 확인합니다.
     */
    func test_makeSyncStateStore_fromContainer_succeeds() async throws {
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeSyncStateStore()

        try await store.save(
            SyncStateRecord(
                namespace: "prod",
                cursor: "cursor-prod",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 700)
            )
        )

        let records = try await store.fetchAll()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.namespace, "prod")
        XCTAssertEqual(records.first?.cursor, "cursor-prod")
    }
}

private extension SyncStateStoreTests {
    /*
     테스트용 SyncState store를 생성합니다.

     Returns:
     - in-memory Core Data stack 위에 구성된 SyncStateStore 구현체

     Throws:
     - Core Data stack 초기화에 실패하면 에러를 던집니다.
     */
    func makeStore() async throws -> SyncStateStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataSyncStateStore(coreDataStack: coreDataStack)
    }

    /*
     동기화 상태 테스트 데이터 3건을 저장합니다.

     Parameters:
     - store: 테스트 데이터를 저장할 동기화 상태 store

     Throws:
     - 저장 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func seedRecords(
        on store: SyncStateStoreProtocol
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
