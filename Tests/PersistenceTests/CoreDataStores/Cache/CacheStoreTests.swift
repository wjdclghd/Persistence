//
//  CacheStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/// CacheStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.
final class CacheStoreTests: XCTestCase {
    func test_fetchAll_returnsEntriesSortedByNamespaceAndKeyAscending() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            CacheEntry(
                namespace: "image",
                key: "b",
                payload: Data("image-b".utf8),
                eTag: nil,
                expiresAt: nil,
                createdAt: Date(timeIntervalSince1970: 300),
                version: 3
            )
        )
        try await store.save(
            CacheEntry(
                namespace: "api",
                key: "a",
                payload: Data("api-a".utf8),
                eTag: nil,
                expiresAt: nil,
                createdAt: Date(timeIntervalSince1970: 100),
                version: 1
            )
        )
        try await store.save(
            CacheEntry(
                namespace: "image",
                key: "a",
                payload: Data("image-a".utf8),
                eTag: nil,
                expiresAt: nil,
                createdAt: Date(timeIntervalSince1970: 200),
                version: 2
            )
        )

        // when
        let entries = try await store.fetchAll()

        // then
        XCTAssertEqual(entries.map(\.namespace), ["api", "image", "image"])
        XCTAssertEqual(entries.map(\.key), ["a", "a", "b"])
    }

    func test_save_withExistingCompositeKey_updatesExistingEntry() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            CacheEntry(
                namespace: "api",
                key: "home",
                payload: Data("v1".utf8),
                eTag: "etag-1",
                expiresAt: Date(timeIntervalSince1970: 100),
                createdAt: Date(timeIntervalSince1970: 100),
                version: 1
            )
        )

        // when
        try await store.save(
            CacheEntry(
                namespace: "api",
                key: "home",
                payload: Data("v2".utf8),
                eTag: "etag-2",
                expiresAt: Date(timeIntervalSince1970: 500),
                createdAt: Date(timeIntervalSince1970: 500),
                version: 2
            )
        )
        let entries = try await store.fetchAll()

        // then
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.namespace, "api")
        XCTAssertEqual(entries.first?.key, "home")
        XCTAssertEqual(entries.first?.payload, Data("v2".utf8))
        XCTAssertEqual(entries.first?.eTag, "etag-2")
        XCTAssertEqual(entries.first?.expiresAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(entries.first?.version, 2)
    }

    func test_fetchEntries_inNamespace_returnsFilteredResults() async throws {
        // given
        let store = try await makeStore()
        try await seedEntries(on: store)

        // when
        let entries = try await store.fetchEntries(in: "image")

        // then
        XCTAssertEqual(entries.map(\.key), ["detail", "thumbnail"])
        XCTAssertTrue(entries.allSatisfy { $0.namespace == "image" })
    }

    func test_fetchEntry_returnsMatchingEntry() async throws {
        // given
        let store = try await makeStore()
        try await seedEntries(on: store)

        // when
        let entry = try await store.fetchEntry(namespace: "api", key: "home")

        // then
        XCTAssertEqual(entry?.namespace, "api")
        XCTAssertEqual(entry?.key, "home")
        XCTAssertEqual(entry?.payload, Data("home-payload".utf8))
        XCTAssertEqual(entry?.version, 1)
    }

    func test_save_withBlankETag_normalizesToNil() async throws {
        // given
        let store = try await makeStore()

        // when
        try await store.save(
            CacheEntry(
                namespace: "api",
                key: "home",
                payload: Data("payload".utf8),
                eTag: "   ",
                expiresAt: nil,
                createdAt: Date(timeIntervalSince1970: 100),
                version: 1
            )
        )
        let entry = try await store.fetchEntry(namespace: "api", key: "home")

        // then
        XCTAssertEqual(entry?.namespace, "api")
        XCTAssertNil(entry?.eTag)
    }

    func test_delete_removesOnlyMatchingEntry() async throws {
        // given
        let store = try await makeStore()
        try await seedEntries(on: store)

        // when
        try await store.delete(namespace: "api", key: "home")
        let entries = try await store.fetchAll()
        let deletedEntry = try await store.fetchEntry(namespace: "api", key: "home")

        // then
        XCTAssertEqual(entries.count, 2)
        XCTAssertNil(deletedEntry)
    }

    func test_deleteEntries_inNamespace_removesOnlyMatchingNamespace() async throws {
        // given
        let store = try await makeStore()
        try await seedEntries(on: store)

        // when
        try await store.deleteEntries(in: "image")
        let entries = try await store.fetchAll()

        // then
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.namespace, "api")
        XCTAssertEqual(entries.first?.key, "home")
    }

    func test_deleteAll_removesAllEntries() async throws {
        // given
        let store = try await makeStore()
        try await seedEntries(on: store)

        // when
        try await store.deleteAll()
        let entries = try await store.fetchAll()

        // then
        XCTAssertTrue(entries.isEmpty)
    }

    func test_save_withBlankNamespace_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()

        // when / then
        do {
            try await store.save(
                CacheEntry(
                    namespace: "   ",
                    key: "home",
                    payload: Data("payload".utf8),
                    eTag: nil,
                    expiresAt: nil,
                    createdAt: Date(),
                    version: 1
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

    func test_save_withBlankKey_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()

        // when / then
        do {
            try await store.save(
                CacheEntry(
                    namespace: "api",
                    key: "   ",
                    payload: Data("payload".utf8),
                    eTag: nil,
                    expiresAt: nil,
                    createdAt: Date(),
                    version: 1
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

    func test_makeCacheStore_fromContainer_succeeds() async throws {
        // given
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeCacheStore()

        // when
        try await store.save(
            CacheEntry(
                namespace: "api",
                key: "startup",
                payload: Data("startup-payload".utf8),
                eTag: "etag-startup",
                expiresAt: Date(timeIntervalSince1970: 700),
                createdAt: Date(timeIntervalSince1970: 700),
                version: 7
            )
        )
        let entries = try await store.fetchAll()

        // then
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.namespace, "api")
        XCTAssertEqual(entries.first?.key, "startup")
    }
}

private extension CacheStoreTests {
    /// 테스트용 Cache store를 생성합니다.
    ///
    /// - Returns:
    /// - in-memory Core Data stack 위에 구성된 CacheStore 구현체
    ///
    /// - Throws:
    /// - Core Data stack 초기화에 실패하면 에러를 던집니다.
    func makeStore() async throws -> any CacheStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataCacheStore(coreDataStack: coreDataStack)
    }

    /// 캐시 테스트 데이터 3건을 저장합니다.
    ///
    /// - Parameters:
    ///   - store: 테스트 데이터를 저장할 캐시 store
    ///
    /// - Throws:
    /// - 저장 과정에서 오류가 발생하면 에러를 던집니다.
    func seedEntries(on store: any CacheStoreProtocol) async throws {
        try await store.save(
            CacheEntry(
                namespace: "api",
                key: "home",
                payload: Data("home-payload".utf8),
                eTag: "etag-home",
                expiresAt: Date(timeIntervalSince1970: 100),
                createdAt: Date(timeIntervalSince1970: 100),
                version: 1
            )
        )
        try await store.save(
            CacheEntry(
                namespace: "image",
                key: "thumbnail",
                payload: Data("thumbnail-payload".utf8),
                eTag: nil,
                expiresAt: Date(timeIntervalSince1970: 200),
                createdAt: Date(timeIntervalSince1970: 200),
                version: 2
            )
        )
        try await store.save(
            CacheEntry(
                namespace: "image",
                key: "detail",
                payload: Data("detail-payload".utf8),
                eTag: nil,
                expiresAt: Date(timeIntervalSince1970: 300),
                createdAt: Date(timeIntervalSince1970: 300),
                version: 3
            )
        )
    }
}
