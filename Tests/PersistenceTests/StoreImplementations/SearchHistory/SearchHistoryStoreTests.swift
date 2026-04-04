//
//  SearchHistoryStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/*
 SearchHistoryStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.

 이 테스트는 in-memory Core Data 환경에서 검색 기록 store가
 정렬 규칙, keyword 기준 upsert, 부분 일치 조회,
 개별 삭제와 전체 삭제를 올바르게 수행하는지 확인합니다.
 또한 PersistenceContainer 조립 지점에서 검색 기록 store를 생성해도
 동일한 동작을 제공하는지 함께 검증합니다.
 */
final class SearchHistoryStoreTests: XCTestCase {
    /*
     저장 후 전체 조회 시 마지막 검색 시각 내림차순으로 정렬되는지 검증합니다.

     최근 검색어가 목록 상단에 와야 하므로,
     저장 순서와 무관하게 정렬 규칙이 유지되는지 확인합니다.
     */
    func test_fetchAll_returnsRecordsSortedByLastSearchedAtDescending() async throws {
        let store = try await makeStore()

        try await store.save(
            SearchHistoryRecord(
                keyword: "swift",
                lastSearchedAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await store.save(
            SearchHistoryRecord(
                keyword: "combine",
                lastSearchedAt: Date(timeIntervalSince1970: 300)
            )
        )
        try await store.save(
            SearchHistoryRecord(
                keyword: "uikit",
                lastSearchedAt: Date(timeIntervalSince1970: 200)
            )
        )

        let records = try await store.fetchAll()

        XCTAssertEqual(records.map(\.keyword), ["combine", "uikit", "swift"])
    }

    /*
     동일 keyword를 다시 저장하면 중복이 생기지 않고 기존 레코드가 갱신되는지 검증합니다.

     검색 기록은 keyword를 기준으로 uniqueness를 유지해야 하므로,
     같은 키워드를 다시 저장할 때 새 레코드를 추가하지 않고 lastSearchedAt만 갱신해야 합니다.
     */
    func test_save_withExistingKeyword_updatesExistingRecord() async throws {
        let store = try await makeStore()

        try await store.save(
            SearchHistoryRecord(
                keyword: "swiftui",
                lastSearchedAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await store.save(
            SearchHistoryRecord(
                keyword: "swiftui",
                lastSearchedAt: Date(timeIntervalSince1970: 500)
            )
        )

        let records = try await store.fetchAll()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.keyword, "swiftui")
        XCTAssertEqual(records.first?.lastSearchedAt, Date(timeIntervalSince1970: 500))
    }

    /*
     키워드 필터 조회가 대소문자를 구분하지 않는 부분 일치로 동작하는지 검증합니다.

     검색 화면에서 입력 중인 텍스트를 기준으로 기존 기록을 빠르게 필터링할 수 있어야 하므로,
     contains[cd] 조건이 의도대로 적용되는지 확인합니다.
     */
    func test_fetchRecords_matchingKeyword_returnsCaseInsensitiveContainsResults() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)

        let records = try await store.fetchRecords(matching: "swi")

        XCTAssertEqual(records.map(\.keyword), ["SwiftUI", "swift"])
    }

    /*
     공백만 전달한 키워드 조회가 전체 목록 조회와 동일하게 동작하는지 검증합니다.

     검색 입력값이 비어 있는 상태에서는 전체 최근 검색 기록을 보여주는 흐름이 많으므로,
     store 계층에서도 같은 규칙을 제공하는지 확인합니다.
     */
    func test_fetchRecords_withBlankKeyword_returnsAllRecords() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)

        let records = try await store.fetchRecords(matching: "   ")

        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records.map(\.keyword), ["SwiftUI", "combine", "swift"])
    }

    /*
     특정 keyword를 삭제하면 해당 레코드만 제거되는지 검증합니다.

     개별 검색 기록 삭제 기능에서 정확한 레코드만 제거되어야 하므로,
     나머지 기록은 유지되는지 함께 확인합니다.
     */
    func test_delete_removesOnlyMatchingRecord() async throws {
        let store = try await makeStore()

        try await seedRecords(on: store)
        try await store.delete(keyword: "combine")

        let records = try await store.fetchAll()

        XCTAssertEqual(records.map(\.keyword), ["SwiftUI", "swift"])
    }

    /*
     전체 삭제가 모든 검색 기록을 제거하는지 검증합니다.

     최근 검색 기록 전체 삭제 기능을 지원하기 위해,
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
     공백 keyword 저장 시 writeFailed가 발생하는지 검증합니다.

     의미 없는 검색 기록이 저장소에 남지 않도록,
     저장 시점에 최소한의 입력값 검증이 수행되는지 확인합니다.
     */
    func test_save_withBlankKeyword_throwsWriteFailed() async throws {
        let store = try await makeStore()

        do {
            try await store.save(
                SearchHistoryRecord(
                    keyword: "   ",
                    lastSearchedAt: Date()
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
     PersistenceContainer가 조립한 검색 기록 store도 정상 동작하는지 검증합니다.

     상위 계층은 CoreDataSearchHistoryStore 구체 타입 대신
     컨테이너 조립 지점을 통해 store를 받게 되므로,
     실제 조립 결과가 올바른 계약 구현체인지 확인합니다.
     */
    func test_makeSearchHistoryStore_fromContainer_succeeds() async throws {
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeSearchHistoryStore()

        try await store.save(
            SearchHistoryRecord(
                keyword: "architecture",
                lastSearchedAt: Date(timeIntervalSince1970: 700)
            )
        )

        let records = try await store.fetchAll()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.keyword, "architecture")
    }
}

private extension SearchHistoryStoreTests {
    /*
     테스트용 SearchHistory store를 생성합니다.

     Returns:
     - in-memory Core Data stack 위에 구성된 SearchHistoryStore 구현체

     Throws:
     - Core Data stack 초기화에 실패하면 에러를 던집니다.
     */
    func makeStore() async throws -> SearchHistoryStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataSearchHistoryStore(coreDataStack: coreDataStack)
    }

    /*
     검색 기록 테스트 데이터 3건을 저장합니다.

     Parameters:
     - store: 테스트 데이터를 저장할 검색 기록 store

     Throws:
     - 저장 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func seedRecords(
        on store: SearchHistoryStoreProtocol
    ) async throws {
        try await store.save(
            SearchHistoryRecord(
                keyword: "swift",
                lastSearchedAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await store.save(
            SearchHistoryRecord(
                keyword: "SwiftUI",
                lastSearchedAt: Date(timeIntervalSince1970: 300)
            )
        )
        try await store.save(
            SearchHistoryRecord(
                keyword: "combine",
                lastSearchedAt: Date(timeIntervalSince1970: 200)
            )
        )
    }
}
