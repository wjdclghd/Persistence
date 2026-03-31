//
//  CacheStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/*
 CacheStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.

 이 테스트는 in-memory Core Data 환경에서 캐시 store가
 namespace와 key 조합 기준 upsert,
 정렬 규칙,
 namespace별 조회,
 개별 삭제와 전체 삭제를 올바르게 수행하는지 확인합니다.
 또한 PersistenceContainer 조립 지점에서 캐시 store를 생성해도
 동일한 동작을 제공하는지 함께 검증합니다.
 */
final class CacheStoreTests: XCTestCase {
    /*
     전체 조회 시 namespace 오름차순, key 오름차순으로 정렬되는지 검증합니다.

     캐시 목록을 안정적으로 비교하고 점검할 수 있어야 하므로,
     저장 순서와 무관하게 정렬 규칙이 유지되는지 확인합니다.
     */
    func test_fetchAll_returnsEntriesSortedByNamespaceAndKeyAscending() async throws {
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

        let entries = try await store.fetchAll()

        XCTAssertEqual(entries.map(\.namespace), ["api", "image", "image"])
        XCTAssertEqual(entries.map(\.key), ["a", "a", "b"])
    }

    /*
     동일 namespace와 key 조합을 다시 저장하면 중복이 생기지 않고 기존 항목이 갱신되는지 검증합니다.

     캐시는 namespace와 key 조합을 기준으로 uniqueness를 유지해야 하므로,
     같은 조합을 다시 저장할 때 새 레코드를 추가하지 않고 값만 갱신해야 합니다.
     */
    func test_save_withExistingCompositeKey_updatesExistingEntry() async throws {
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

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.namespace, "api")
        XCTAssertEqual(entries.first?.key, "home")
        XCTAssertEqual(entries.first?.payload, Data("v2".utf8))
        XCTAssertEqual(entries.first?.eTag, "etag-2")
        XCTAssertEqual(entries.first?.expiresAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(entries.first?.version, 2)
    }

    /*
     namespace별 조회가 정확히 필터링되는지 검증합니다.

     캐시 정리나 점검 흐름에서는 특정 namespace의 항목만 나눠 볼 수 있어야 하므로,
     지정한 namespace와 정확히 일치하는 레코드만 반환되는지 확인합니다.
     */
    func test_fetchEntries_inNamespace_returnsFilteredResults() async throws {
        let store = try await makeStore()

        try await seedEntries(on: store)

        let entries = try await store.fetchEntries(in: "image")

        XCTAssertEqual(entries.map(\.key), ["detail", "thumbnail"])
        XCTAssertTrue(entries.allSatisfy { $0.namespace == "image" })
    }

    /*
     namespace와 key가 모두 일치하는 캐시 항목 조회가 가능한지 검증합니다.

     캐시 적중 여부를 빠르게 판단할 수 있어야 하므로,
     정확한 항목이 반환되는지 검증합니다.
     */
    func test_fetchEntry_returnsMatchingEntry() async throws {
        let store = try await makeStore()

        try await seedEntries(on: store)

        let entry = try await store.fetchEntry(namespace: "api", key: "home")

        XCTAssertEqual(entry?.namespace, "api")
        XCTAssertEqual(entry?.key, "home")
        XCTAssertEqual(entry?.payload, Data("home-payload".utf8))
        XCTAssertEqual(entry?.version, 1)
    }

    /*
     공백 eTag가 nil로 정규화되는지 검증합니다.

     캐시 검증 값은 공백 문자열 대신 nil로 보관해야 하므로,
     저장 후 조회 결과가 nil인지 확인합니다.
     */
    func test_save_withBlankETag_normalizesToNil() async throws {
        let store = try await makeStore()

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

        XCTAssertEqual(entry?.namespace, "api")
        XCTAssertNil(entry?.eTag)
    }

    /*
     특정 캐시 항목을 삭제하면 해당 레코드만 제거되는지 검증합니다.

     개별 캐시 무효화 기능에서 정확한 레코드만 제거되어야 하므로,
     나머지 레코드는 유지되는지 함께 확인합니다.
     */
    func test_delete_removesOnlyMatchingEntry() async throws {
        let store = try await makeStore()

        try await seedEntries(on: store)
        try await store.delete(namespace: "api", key: "home")

        let entries = try await store.fetchAll()
        let deletedEntry = try await store.fetchEntry(namespace: "api", key: "home")

        XCTAssertEqual(entries.count, 2)
        XCTAssertNil(deletedEntry)
    }

    /*
     특정 namespace의 캐시 항목을 모두 삭제하면 해당 namespace만 제거되는지 검증합니다.

     namespace 단위 캐시 정리 기능에서 목표 범위만 제거되어야 하므로,
     다른 namespace의 캐시는 유지되는지 함께 확인합니다.
     */
    func test_deleteEntries_inNamespace_removesOnlyMatchingNamespace() async throws {
        let store = try await makeStore()

        try await seedEntries(on: store)
        try await store.deleteEntries(in: "image")

        let entries = try await store.fetchAll()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.namespace, "api")
        XCTAssertEqual(entries.first?.key, "home")
    }

    /*
     전체 삭제가 모든 캐시 항목을 제거하는지 검증합니다.

     전체 캐시 초기화 기능을 지원하기 위해,
     저장된 레코드가 남지 않는지 확인합니다.
     */
    func test_deleteAll_removesAllEntries() async throws {
        let store = try await makeStore()

        try await seedEntries(on: store)
        try await store.deleteAll()

        let entries = try await store.fetchAll()

        XCTAssertTrue(entries.isEmpty)
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

    /*
     공백 key 저장 시 writeFailed가 발생하는지 검증합니다.

     의미 없는 key가 저장소에 남지 않도록,
     저장 시점에 최소한의 입력값 검증이 수행되는지 확인합니다.
     */
    func test_save_withBlankKey_throwsWriteFailed() async throws {
        let store = try await makeStore()

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

    /*
     PersistenceContainer가 조립한 캐시 store도 정상 동작하는지 검증합니다.

     상위 계층은 CoreDataCacheStore 구체 타입 대신
     컨테이너 조립 지점을 통해 store를 받게 되므로,
     실제 조립 결과가 올바른 계약 구현체인지 확인합니다.
     */
    func test_makeCacheStore_fromContainer_succeeds() async throws {
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeCacheStore()

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

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.namespace, "api")
        XCTAssertEqual(entries.first?.key, "startup")
    }
}

private extension CacheStoreTests {
    /*
     테스트용 Cache store를 생성합니다.

     Returns:
     - in-memory Core Data stack 위에 구성된 CacheStore 구현체

     Throws:
     - Core Data stack 초기화에 실패하면 에러를 던집니다.
     */
    func makeStore() async throws -> CacheStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataCacheStore(coreDataStack: coreDataStack)
    }

    /*
     캐시 테스트 데이터 3건을 저장합니다.

     Parameters:
     - store: 테스트 데이터를 저장할 캐시 store

     Throws:
     - 저장 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func seedEntries(on store: CacheStoreProtocol) async throws {
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
