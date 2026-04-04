//
//  FavoriteStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/*
 FavoriteStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.

 이 테스트는 in-memory Core Data 환경에서 즐겨찾기 store가
 정렬 규칙, id와 type 조합 기준 upsert,
 타입별 조회,
 개별 삭제와 전체 삭제를 올바르게 수행하는지 확인합니다.
 또한 PersistenceContainer 조립 지점에서 즐겨찾기 store를 생성해도
 동일한 동작을 제공하는지 함께 검증합니다.
 */
final class FavoriteStoreTests: XCTestCase {
    /*
     저장 후 전체 조회 시 생성 시각 내림차순으로 정렬되는지 검증합니다.

     최근 즐겨찾기가 목록 상단에 와야 하므로,
     저장 순서와 무관하게 정렬 규칙이 유지되는지 확인합니다.
     */
    func test_fetchAll_returnsRecordsSortedByCreatedAtDescending() async throws {
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

        let records = try await store.fetchAll()

        XCTAssertEqual(records.map(\.id), ["200", "300", "100"])
    }

    /*
     동일 id와 type 조합을 다시 저장하면 중복이 생기지 않고 기존 레코드가 갱신되는지 검증합니다.

     즐겨찾기는 id와 type 조합을 기준으로 uniqueness를 유지해야 하므로,
     같은 조합을 다시 저장할 때 새 레코드를 추가하지 않고 createdAt만 갱신해야 합니다.
     */
    func test_save_withExistingCompositeKey_updatesExistingRecord() async throws {
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
                id: "100",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 500)
            )
        )

        let records = try await store.fetchAll()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, "100")
        XCTAssertEqual(records.first?.type, "app")
        XCTAssertEqual(records.first?.createdAt, Date(timeIntervalSince1970: 500))
    }

    /*
     동일 id라도 type이 다르면 별도 레코드로 저장되는지 검증합니다.

     즐겨찾기 식별은 id와 type 조합을 기준으로 하므로,
     type이 다른 경우에는 서로 다른 항목으로 다뤄야 합니다.
     */
    func test_save_withDifferentType_keepsSeparateRecords() async throws {
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
                id: "100",
                type: "movie",
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )

        let records = try await store.fetchAll()

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.map(\.type), ["movie", "app"])
    }

    /*
     타입별 조회가 정확히 필터링되는지 검증합니다.

     즐겨찾기 화면에서 타입별 목록을 나눠 보여줄 수 있어야 하므로,
     지정한 type과 정확히 일치하는 레코드만 반환되는지 확인합니다.
     */
    func test_fetchRecords_ofType_returnsFilteredResults() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)

        let records = try await store.fetchRecords(ofType: "app")

        XCTAssertEqual(records.map(\.id), ["300", "100"])
        XCTAssertTrue(records.allSatisfy { $0.type == "app" })
    }

    /*
     식별자와 타입이 모두 일치하는 즐겨찾기 조회가 가능한지 검증합니다.

     상세 화면이나 상태 복원 흐름에서는 특정 조합의 존재 여부를 빠르게 확인해야 하므로,
     정확한 레코드가 반환되는지 검증합니다.
     */
    func test_fetchRecord_returnsMatchingRecord() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)

        let record = try await store.fetchRecord(id: "200", type: "movie")

        XCTAssertEqual(record?.id, "200")
        XCTAssertEqual(record?.type, "movie")
        XCTAssertEqual(record?.createdAt, Date(timeIntervalSince1970: 300))
    }

    /*
     특정 즐겨찾기를 삭제하면 해당 레코드만 제거되는지 검증합니다.

     개별 즐겨찾기 해제 기능에서 정확한 레코드만 제거되어야 하므로,
     나머지 레코드는 유지되는지 함께 확인합니다.
     */
    func test_delete_removesOnlyMatchingRecord() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)
        try await store.delete(id: "200", type: "movie")

        let records = try await store.fetchAll()
        let deletedRecord = try await store.fetchRecord(id: "200", type: "movie")

        XCTAssertEqual(records.count, 2)
        XCTAssertNil(deletedRecord)
    }

    /*
     전체 삭제가 모든 즐겨찾기를 제거하는지 검증합니다.

     즐겨찾기 전체 초기화 기능을 지원하기 위해,
     저장된 레코드가 남지 않는지 확인합니다.
     */
    func test_deleteAll_removesAllRecords() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)
        try await store.deleteAll()

        let records = try await store.fetchAll()

        XCTAssertTrue(records.isEmpty)
    }

    /*
     공백 id 저장 시 writeFailed가 발생하는지 검증합니다.

     의미 없는 즐겨찾기 레코드가 저장소에 남지 않도록,
     저장 시점에 최소한의 입력값 검증이 수행되는지 확인합니다.
     */
    func test_save_withBlankID_throwsWriteFailed() async throws {
        let store = try await makeStore()

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

    /*
     공백 type 저장 시 writeFailed가 발생하는지 검증합니다.

     타입 정보가 없는 즐겨찾기가 저장소에 남지 않도록,
     저장 시점에 최소한의 입력값 검증이 수행되는지 확인합니다.
     */
    func test_save_withBlankType_throwsWriteFailed() async throws {
        let store = try await makeStore()

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

    /*
     PersistenceContainer가 조립한 즐겨찾기 store도 정상 동작하는지 검증합니다.

     상위 계층은 CoreDataFavoriteStore 구체 타입 대신
     컨테이너 조립 지점을 통해 store를 받게 되므로,
     실제 조립 결과가 올바른 계약 구현체인지 확인합니다.
     */
    func test_makeFavoriteStore_fromContainer_succeeds() async throws {
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeFavoriteStore()

        try await store.save(
            FavoriteRecord(
                id: "999",
                type: "app",
                createdAt: Date(timeIntervalSince1970: 700)
            )
        )

        let records = try await store.fetchAll()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.id, "999")
        XCTAssertEqual(records.first?.type, "app")
    }
}

private extension FavoriteStoreTests {
    /*
     테스트용 Favorite store를 생성합니다.

     Returns:
     - in-memory Core Data stack 위에 구성된 FavoriteStore 구현체

     Throws:
     - Core Data stack 초기화에 실패하면 에러를 던집니다.
     */
    func makeStore() async throws -> FavoriteStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataFavoriteStore(coreDataStack: coreDataStack)
    }

    /*
     즐겨찾기 테스트 데이터 3건을 저장합니다.

     Parameters:
     - store: 테스트 데이터를 저장할 즐겨찾기 store

     Throws:
     - 저장 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func seedRecords(
        on store: FavoriteStoreProtocol
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
