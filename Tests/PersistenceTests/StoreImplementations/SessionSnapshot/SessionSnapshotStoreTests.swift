//
//  SessionSnapshotStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/*
 SessionSnapshotStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.

 이 테스트는 in-memory Core Data 환경에서 세션 스냅샷 store가
 환경 기준 upsert,
 정렬 규칙,
 단건 조회,
 개별 삭제와 전체 삭제를 올바르게 수행하는지 확인합니다.
 또한 PersistenceContainer 조립 지점에서 세션 스냅샷 store를 생성해도
 동일한 동작을 제공하는지 함께 검증합니다.
 */
final class SessionSnapshotStoreTests: XCTestCase {
    /*
     전체 조회 시 environment 오름차순으로 정렬되는지 검증합니다.

     환경별 세션 상태를 안정적으로 표시하기 위해,
     저장 순서와 무관하게 정렬 규칙이 유지되는지 확인합니다.
     */
    func test_fetchAll_returnsSnapshotsSortedByEnvironmentAscending() async throws {
        let store = try await makeStore()

        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 300),
                userID: "user-3"
            )
        )
        try await store.save(
            SessionSnapshot(
                environment: "dev",
                isLoggedIn: false,
                lastRefreshedAt: Date(timeIntervalSince1970: 100),
                userID: nil
            )
        )
        try await store.save(
            SessionSnapshot(
                environment: "stage",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 200),
                userID: "user-2"
            )
        )

        let snapshots = try await store.fetchAll()

        XCTAssertEqual(snapshots.map(\.environment), ["dev", "prod", "stage"])
    }

    /*
     동일 environment를 다시 저장하면 중복이 생기지 않고 기존 스냅샷이 갱신되는지 검증합니다.

     세션 스냅샷은 environment를 기준으로 uniqueness를 유지해야 하므로,
     같은 환경을 다시 저장할 때 새 레코드를 추가하지 않고 값만 갱신해야 합니다.
     */
    func test_save_withExistingEnvironment_updatesExistingSnapshot() async throws {
        let store = try await makeStore()

        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: false,
                lastRefreshedAt: Date(timeIntervalSince1970: 100),
                userID: nil
            )
        )
        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 500),
                userID: "user-500"
            )
        )

        let snapshots = try await store.fetchAll()

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.environment, "prod")
        XCTAssertEqual(snapshots.first?.isLoggedIn, true)
        XCTAssertEqual(snapshots.first?.lastRefreshedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(snapshots.first?.userID, "user-500")
    }

    /*
     지정한 environment의 세션 스냅샷을 조회할 수 있는지 검증합니다.

     앱 시작 시 특정 환경의 로그인 상태를 복원할 수 있어야 하므로,
     정확한 스냅샷이 반환되는지 확인합니다.
     */
    func test_fetchSnapshot_returnsMatchingSnapshot() async throws {
        let store = try await makeStore()

        try await seedSnapshots(on: store)

        let snapshot = try await store.fetchSnapshot(for: "stage")

        XCTAssertEqual(snapshot?.environment, "stage")
        XCTAssertEqual(snapshot?.isLoggedIn, true)
        XCTAssertEqual(snapshot?.lastRefreshedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(snapshot?.userID, "user-stage")
    }

    /*
     공백 environment 저장 시 writeFailed가 발생하는지 검증합니다.

     의미 없는 환경 식별자가 저장소에 남지 않도록,
     저장 시점에 최소한의 입력값 검증이 수행되는지 확인합니다.
     */
    func test_save_withBlankEnvironment_throwsWriteFailed() async throws {
        let store = try await makeStore()

        do {
            try await store.save(
                SessionSnapshot(
                    environment: "   ",
                    isLoggedIn: false,
                    lastRefreshedAt: Date(),
                    userID: nil
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
     공백 userID가 nil로 정규화되는지 검증합니다.

     세션 스냅샷은 공백 문자열 대신 nil로 사용자 식별자를 보관해야 하므로,
     저장 후 조회 결과가 nil인지 확인합니다.
     */
    func test_save_withBlankUserID_normalizesToNil() async throws {
        let store = try await makeStore()

        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 300),
                userID: "   "
            )
        )

        let snapshot = try await store.fetchSnapshot(for: "prod")

        XCTAssertEqual(snapshot?.environment, "prod")
        XCTAssertNil(snapshot?.userID)
    }

    /*
     특정 environment를 삭제하면 해당 스냅샷만 제거되는지 검증합니다.

     환경별 세션 초기화 기능에서 정확한 스냅샷만 제거되어야 하므로,
     나머지 스냅샷은 유지되는지 함께 확인합니다.
     */
    func test_delete_removesOnlyMatchingSnapshot() async throws {
        let store = try await makeStore()

        try await seedSnapshots(on: store)
        try await store.delete(environment: "stage")

        let snapshots = try await store.fetchAll()
        let deletedSnapshot = try await store.fetchSnapshot(for: "stage")

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertNil(deletedSnapshot)
    }

    /*
     전체 삭제가 모든 세션 스냅샷을 제거하는지 검증합니다.

     세션 상태 전체 초기화 기능을 지원하기 위해,
     저장된 스냅샷이 남지 않는지 확인합니다.
     */
    func test_deleteAll_removesAllSnapshots() async throws {
        let store = try await makeStore()

        try await seedSnapshots(on: store)
        try await store.deleteAll()

        let snapshots = try await store.fetchAll()

        XCTAssertTrue(snapshots.isEmpty)
    }

    /*
     PersistenceContainer가 조립한 세션 스냅샷 store도 정상 동작하는지 검증합니다.

     상위 계층은 CoreDataSessionSnapshotStore 구체 타입 대신
     컨테이너 조립 지점을 통해 store를 받게 되므로,
     실제 조립 결과가 올바른 계약 구현체인지 확인합니다.
     */
    func test_makeSessionSnapshotStore_fromContainer_succeeds() async throws {
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeSessionSnapshotStore()

        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 700),
                userID: "user-prod"
            )
        )

        let snapshots = try await store.fetchAll()

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.environment, "prod")
        XCTAssertEqual(snapshots.first?.userID, "user-prod")
    }
}

private extension SessionSnapshotStoreTests {
    /*
     테스트용 SessionSnapshot store를 생성합니다.

     Returns:
     - in-memory Core Data stack 위에 구성된 SessionSnapshotStore 구현체

     Throws:
     - Core Data stack 초기화에 실패하면 에러를 던집니다.
     */
    func makeStore() async throws -> SessionSnapshotStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataSessionSnapshotStore(coreDataStack: coreDataStack)
    }

    /*
     세션 스냅샷 테스트 데이터 3건을 저장합니다.

     Parameters:
     - store: 테스트 데이터를 저장할 세션 스냅샷 store

     Throws:
     - 저장 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func seedSnapshots(
        on store: SessionSnapshotStoreProtocol
    ) async throws {
        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 300),
                userID: "user-prod"
            )
        )
        try await store.save(
            SessionSnapshot(
                environment: "dev",
                isLoggedIn: false,
                lastRefreshedAt: Date(timeIntervalSince1970: 100),
                userID: nil
            )
        )
        try await store.save(
            SessionSnapshot(
                environment: "stage",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 200),
                userID: "user-stage"
            )
        )
    }
}
