//
//  PersistenceContainerTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/*
 PersistenceContainer의 생성과 저장소 조립 동작을 검증하는 테스트입니다.

 이 테스트는 programmatic model 기반 in-memory 환경에서
 PersistenceContainer가 정상적으로 생성되는지,
 컨테이너가 노출하는 각 저장소 조립 메서드가 실제로 동작 가능한 구현체를 반환하는지 확인합니다.
 또한 컨테이너 생성 시 전달한 설정값이 유지되는지도 함께 검증합니다.
 */
final class PersistenceContainerTests: XCTestCase {
    /*
     지정한 설정으로 PersistenceContainer를 생성하면 같은 설정값이 유지되는지 검증합니다.

     컨테이너는 상위 계층이 사용하는 조립 진입점이므로,
     생성 시 사용한 설정을 안정적으로 보관하고 있어야 이후 디버깅과 구성 확인에 도움이 됩니다.
     */
    func test_make_withProgrammaticInMemoryConfiguration_keepsConfiguration() async throws {
        let configuration = PersistenceConfiguration.inMemory(
            modelSource: ProgrammaticPersistenceModel.defaultSource(),
            migrationPlan: .disabled
        )

        let container = try await PersistenceContainer.make(configuration: configuration)

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

    /*
     기본 programmatic in-memory 컨테이너를 생성할 수 있는지 검증합니다.

     테스트, 샘플 실행, Preview 같은 환경에서는
     리소스 번들 없이도 기본 모델로 빠르게 컨테이너를 만들 수 있어야 하므로,
     편의 생성 메서드가 의도한 구성을 반환하는지 확인합니다.
     */
    func test_makeDefaultProgrammaticInMemory_createsInMemoryContainer() async throws {
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()

        XCTAssertEqual(container.configuration.modelName, "PersistenceModel")
        XCTAssertEqual(container.configuration.storeKind, .inMemory)
    }

    /*
     컨테이너가 조립한 검색 기록 저장소가 정상적으로 저장과 조회를 수행하는지 검증합니다.

     상위 계층은 컨테이너가 반환한 protocol 계약만 사용하므로,
     조립 결과가 실제로 동작 가능한 저장소인지 간단한 round-trip으로 확인합니다.
     */
    func test_makeSearchHistoryStore_fromContainer_savesAndFetchesRecord() async throws {
        let container = try await makeContainer()
        let store = container.makeSearchHistoryStore()

        try await store.save(
            SearchHistoryRecord(
                keyword: "swiftui",
                lastSearchedAt: Date(timeIntervalSince1970: 100)
            )
        )

        let records = try await store.fetchAll()

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.keyword, "swiftui")
        XCTAssertEqual(records.first?.lastSearchedAt, Date(timeIntervalSince1970: 100))
    }

    /*
     컨테이너가 조립한 즐겨찾기 저장소가 정상적으로 저장과 조회를 수행하는지 검증합니다.

     컨테이너 조립 지점을 통해 받은 store도
     직접 생성한 구현체와 동일한 계약 동작을 제공해야 합니다.
     */
    func test_makeFavoriteStore_fromContainer_savesAndFetchesRecord() async throws {
        let container = try await makeContainer()
        let store = container.makeFavoriteStore()

        try await store.save(
            FavoriteRecord(
                id: "place-1",
                type: "lodging",
                createdAt: Date(timeIntervalSince1970: 200)
            )
        )

        let record = try await store.fetchRecord(id: "place-1", type: "lodging")

        XCTAssertEqual(record?.id, "place-1")
        XCTAssertEqual(record?.type, "lodging")
        XCTAssertEqual(record?.createdAt, Date(timeIntervalSince1970: 200))
    }

    /*
     컨테이너가 조립한 세션 스냅샷 저장소가 정상적으로 저장과 조회를 수행하는지 검증합니다.

     세션 복원 경로는 앱 시작 시 바로 사용될 수 있으므로,
     컨테이너를 통해 생성한 store가 환경 기준 단건 조회를 안정적으로 처리하는지 확인합니다.
     */
    func test_makeSessionSnapshotStore_fromContainer_savesAndFetchesSnapshot() async throws {
        let container = try await makeContainer()
        let store = container.makeSessionSnapshotStore()

        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 300),
                userID: "user-1"
            )
        )

        let snapshot = try await store.fetchSnapshot(for: "prod")

        XCTAssertEqual(snapshot?.environment, "prod")
        XCTAssertEqual(snapshot?.isLoggedIn, true)
        XCTAssertEqual(snapshot?.lastRefreshedAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(snapshot?.userID, "user-1")
    }

    /*
     컨테이너가 조립한 캐시 저장소가 정상적으로 저장과 조회를 수행하는지 검증합니다.

     네트워크 응답 캐시 같은 기능은 namespace와 key 기반 조회가 중요하므로,
     컨테이너 경유 store에서도 동일한 조회 흐름이 동작하는지 확인합니다.
     */
    func test_makeCacheStore_fromContainer_savesAndFetchesEntry() async throws {
        let container = try await makeContainer()
        let store = container.makeCacheStore()

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

        XCTAssertEqual(entry?.namespace, "api")
        XCTAssertEqual(entry?.key, "home")
        XCTAssertEqual(entry?.payload, Data("payload".utf8))
        XCTAssertEqual(entry?.eTag, "etag-1")
        XCTAssertEqual(entry?.expiresAt, Date(timeIntervalSince1970: 400))
        XCTAssertEqual(entry?.version, 1)
    }

    /*
     컨테이너가 조립한 동기화 상태 저장소가 정상적으로 저장과 조회를 수행하는지 검증합니다.

     동기화 재개 지점 복원은 namespace 기준 단건 조회에 의존하므로,
     컨테이너 조립 결과가 같은 계약 동작을 제공하는지 확인합니다.
     */
    func test_makeSyncStateStore_fromContainer_savesAndFetchesRecord() async throws {
        let container = try await makeContainer()
        let store = container.makeSyncStateStore()

        try await store.save(
            SyncStateRecord(
                namespace: "orders",
                cursor: "cursor-1",
                isDirty: true,
                lastSyncedAt: Date(timeIntervalSince1970: 500)
            )
        )

        let record = try await store.fetchRecord(for: "orders")

        XCTAssertEqual(record?.namespace, "orders")
        XCTAssertEqual(record?.cursor, "cursor-1")
        XCTAssertEqual(record?.isDirty, true)
        XCTAssertEqual(record?.lastSyncedAt, Date(timeIntervalSince1970: 500))
    }
}

private extension PersistenceContainerTests {
    /*
     테스트용 PersistenceContainer를 생성합니다.

     programmatic model 기반 in-memory 환경을 사용하여,
     파일 시스템 정리 없이 독립적인 컨테이너 테스트를 수행할 수 있도록 구성합니다.

     Returns:
     - 테스트에서 바로 사용할 수 있는 PersistenceContainer

     Throws:
     - Core Data stack 초기화에 실패하면 에러를 던집니다.
     */
    func makeContainer() async throws -> PersistenceContainer {
        try await PersistenceContainer.make(
            configuration: .inMemory(
                modelSource: ProgrammaticPersistenceModel.defaultSource()
            )
        )
    }
}
