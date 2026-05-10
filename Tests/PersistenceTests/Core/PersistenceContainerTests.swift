//
//  PersistenceContainerTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/// PersistenceContainer의 생성과 저장소 조립 동작을 검증하는 테스트입니다.
final class PersistenceContainerTests: XCTestCase {
    func test_make_withProgrammaticInMemoryConfiguration_keepsConfiguration() async throws {
        // given
        let configuration = PersistenceConfiguration.inMemory(
            modelSource: ProgrammaticPersistenceModel.defaultSource(),
            migrationPlan: .disabled
        )

        // when
        let container = try await PersistenceContainer.make(configuration: configuration)

        // then
        XCTAssertEqual(container.configuration.modelName, configuration.modelName)
        XCTAssertEqual(container.configuration.storeKind, .inMemory)
        XCTAssertEqual(
            container.configuration.migrationPlan.shouldMigrateStoreAutomatically,
            configuration.migrationPlan.shouldMigrateStoreAutomatically
        )
        XCTAssertEqual(
            container.configuration.migrationPlan.shouldInferMappingModelAutomatically,
            configuration.migrationPlan.shouldInferMappingModelAutomatically
        )
    }

    func test_makeDefaultProgrammaticInMemory_createsInMemoryContainer() async throws {
        // given / when
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()

        // then
        XCTAssertEqual(container.configuration.modelName, "PersistenceModel")
        XCTAssertEqual(container.configuration.storeKind, .inMemory)
    }

    func test_makeSearchHistoryStore_fromContainer_savesAndFetchesRecord() async throws {
        // given
        let container = try await makeContainer()
        let store = container.makeSearchHistoryStore()

        // when
        try await store.save(
            SearchHistoryRecord(
                keyword: "swiftui",
                lastSearchedAt: Date(timeIntervalSince1970: 100)
            )
        )
        let records = try await store.fetchAll()

        // then
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.keyword, "swiftui")
        XCTAssertEqual(records.first?.lastSearchedAt, Date(timeIntervalSince1970: 100))
    }

    func test_makeFavoriteStore_fromContainer_savesAndFetchesRecord() async throws {
        // given
        let container = try await makeContainer()
        let store = container.makeFavoriteStore()

        // when
        try await store.save(
            FavoriteRecord(
                id: "place-1",
                type: "lodging",
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )
        let record = try await store.fetchRecord(id: "place-1", type: "lodging")

        // then
        XCTAssertEqual(record?.id, "place-1")
        XCTAssertEqual(record?.type, "lodging")
        XCTAssertEqual(record?.createdAt, Date(timeIntervalSince1970: 200))
    }

    func test_makeSessionSnapshotStore_fromContainer_savesAndFetchesSnapshot() async throws {
        // given
        let container = try await makeContainer()
        let store = container.makeSessionSnapshotStore()

        // when
        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 300),
                userID: "user-1"
            )
        )
        let snapshot = try await store.fetchSnapshot(for: "prod")

        // then
        XCTAssertEqual(snapshot?.environment, "prod")
        XCTAssertEqual(snapshot?.isLoggedIn, true)
        XCTAssertEqual(snapshot?.lastRefreshedAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(snapshot?.userID, "user-1")
    }

    func test_makeCacheStore_fromContainer_savesAndFetchesEntry() async throws {
        // given
        let container = try await makeContainer()
        let store = container.makeCacheStore()

        // when
        try await store.save(
            CacheEntry(
                namespace: "api",
                key: "home",
                payload: Data("payload".utf8),
                eTag: "etag-1",
                expiresAt: Date(timeIntervalSince1970: 400),
                createdAt: Date(timeIntervalSince1970: 350),
                version: 1
            )
        )
        let entry = try await store.fetchEntry(namespace: "api", key: "home")

        // then
        XCTAssertEqual(entry?.namespace, "api")
        XCTAssertEqual(entry?.key, "home")
        XCTAssertEqual(entry?.payload, Data("payload".utf8))
        XCTAssertEqual(entry?.eTag, "etag-1")
        XCTAssertEqual(entry?.expiresAt, Date(timeIntervalSince1970: 400))
        XCTAssertEqual(entry?.version, 1)
    }

    func test_makeSyncStateStore_fromContainer_savesAndFetchesRecord() async throws {
        // given
        let container = try await makeContainer()
        let store = container.makeSyncStateStore()

        // when
        try await store.save(
            SyncStateRecord(
                namespace: "orders",
                cursor: "cursor-1",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 500)
            )
        )
        let record = try await store.fetchRecord(for: "orders")

        // then
        XCTAssertEqual(record?.namespace, "orders")
        XCTAssertEqual(record?.cursor, "cursor-1")
        XCTAssertEqual(record?.isDirty, true)
        XCTAssertEqual(record?.lastSyncedAt, Date(timeIntervalSince1970: 500))
    }
}

private extension PersistenceContainerTests {
    func makeContainer() async throws -> PersistenceContainer {
        try await PersistenceContainer.make(
            configuration: .inMemory(
                modelSource: ProgrammaticPersistenceModel.defaultSource()
            )
        )
    }
}
