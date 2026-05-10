//
//  SearchHistoryStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/// SearchHistoryStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.
final class SearchHistoryStoreTests: XCTestCase {
    func test_fetchAll_returnsRecordsSortedByLastSearchedAtDescending() async throws {
        // given
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

        // when
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.map(\.keyword), ["combine", "uikit", "swift"])
    }

    func test_save_withExistingKeyword_updatesExistingRecord() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            SearchHistoryRecord(
                keyword: "swiftui",
                lastSearchedAt: Date(timeIntervalSince1970: 100)
            )
        )

        // when
        try await store.save(
            SearchHistoryRecord(
                keyword: "swiftui",
                lastSearchedAt: Date(timeIntervalSince1970: 500)
            )
        )
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.keyword, "swiftui")
        XCTAssertEqual(records.first?.lastSearchedAt, Date(timeIntervalSince1970: 500))
    }

    func test_save_withCaseVariantKeyword_updatesExistingRecord() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            SearchHistoryRecord(
                keyword: "Music",
                lastSearchedAt: Date(timeIntervalSince1970: 100)
            )
        )

        // when
        try await store.save(
            SearchHistoryRecord(
                keyword: "music",
                lastSearchedAt: Date(timeIntervalSince1970: 500)
            )
        )
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.keyword, "music")
        XCTAssertEqual(records.first?.lastSearchedAt, Date(timeIntervalSince1970: 500))
    }

    func test_save_whenRecordCountExceedsMaximumLimit_removesOldestRecords() async throws {
        // given
        let store = try await makeStore()
        for index in 0..<31 {
            try await store.save(
                SearchHistoryRecord(
                    keyword: "keyword-\(index)",
                    lastSearchedAt: Date(timeIntervalSince1970: TimeInterval(index))
                )
            )
        }

        // when
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 30)
        XCTAssertEqual(records.first?.keyword, "keyword-30")
        XCTAssertEqual(records.last?.keyword, "keyword-1")
        XCTAssertFalse(records.contains { $0.keyword == "keyword-0" })
    }

    func test_fetchRecords_matchingKeyword_returnsCaseInsensitiveContainsResults() async throws {
        // given
        let store = try await makeStore()
        try await seedRecords(on: store)

        // when
        let records = try await store.fetchRecords(matching: "swi")

        // then
        XCTAssertEqual(records.map(\.keyword), ["SwiftUI", "swift"])
    }

    func test_fetchRecords_withBlankKeyword_returnsAllRecords() async throws {
        // given
        let store = try await makeStore()
        try await seedRecords(on: store)

        // when
        let records = try await store.fetchRecords(matching: "   ")

        // then
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records.map(\.keyword), ["SwiftUI", "combine", "swift"])
    }

    func test_delete_removesOnlyMatchingRecord() async throws {
        // given
        let store = try await makeStore()
        try await seedRecords(on: store)

        // when
        try await store.delete(keyword: "combine")
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.map(\.keyword), ["SwiftUI", "swift"])
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

    func test_save_withBlankKeyword_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()

        // when / then
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

    func test_makeSearchHistoryStore_fromContainer_succeeds() async throws {
        // given
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeSearchHistoryStore()

        // when
        try await store.save(
            SearchHistoryRecord(
                keyword: "architecture",
                lastSearchedAt: Date(timeIntervalSince1970: 700)
            )
        )
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.keyword, "architecture")
    }
}

private extension SearchHistoryStoreTests {
    /// 테스트용 SearchHistory store를 생성합니다.
    ///
    /// - Returns:
    /// - in-memory Core Data stack 위에 구성된 SearchHistoryStore 구현체
    ///
    /// - Throws:
    /// - Core Data stack 초기화에 실패하면 에러를 던집니다.
    func makeStore() async throws -> any SearchHistoryStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataSearchHistoryStore(coreDataStack: coreDataStack)
    }

    /// 검색 기록 테스트 데이터 3건을 저장합니다.
    ///
    /// - Parameters:
    ///   - store: 테스트 데이터를 저장할 검색 기록 store
    ///
    /// - Throws:
    /// - 저장 과정에서 오류가 발생하면 에러를 던집니다.
    func seedRecords(
        on store: any SearchHistoryStoreProtocol
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
