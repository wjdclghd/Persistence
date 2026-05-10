//
//  SessionSnapshotStoreTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import XCTest
@testable import Persistence

/// SessionSnapshotStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.
final class SessionSnapshotStoreTests: XCTestCase {
    func test_fetchAll_returnsSnapshotsSortedByEnvironmentAscending() async throws {
        // given
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

        // when
        let snapshots = try await store.fetchAll()

        // then
        XCTAssertEqual(snapshots.map(\.environment), ["dev", "prod", "stage"])
    }

    func test_save_withExistingEnvironment_updatesExistingSnapshot() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: false,
                lastRefreshedAt: Date(timeIntervalSince1970: 100),
                userID: nil
            )
        )

        // when
        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 500),
                userID: "user-500"
            )
        )
        let snapshots = try await store.fetchAll()

        // then
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.environment, "prod")
        XCTAssertEqual(snapshots.first?.isLoggedIn, true)
        XCTAssertEqual(snapshots.first?.lastRefreshedAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(snapshots.first?.userID, "user-500")
    }

    func test_fetchSnapshot_returnsMatchingSnapshot() async throws {
        // given
        let store = try await makeStore()
        try await seedSnapshots(on: store)

        // when
        let snapshot = try await store.fetchSnapshot(for: "stage")

        // then
        XCTAssertEqual(snapshot?.environment, "stage")
        XCTAssertEqual(snapshot?.isLoggedIn, true)
        XCTAssertEqual(snapshot?.lastRefreshedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(snapshot?.userID, "user-stage")
    }

    func test_save_withBlankEnvironment_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()

        // when / then
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

    func test_save_withBlankUserID_normalizesToNil() async throws {
        // given
        let store = try await makeStore()

        // when
        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 300),
                userID: "   "
            )
        )
        let snapshot = try await store.fetchSnapshot(for: "prod")

        // then
        XCTAssertEqual(snapshot?.environment, "prod")
        XCTAssertNil(snapshot?.userID)
    }

    func test_delete_removesOnlyMatchingSnapshot() async throws {
        // given
        let store = try await makeStore()
        try await seedSnapshots(on: store)

        // when
        try await store.delete(environment: "stage")
        let snapshots = try await store.fetchAll()
        let deletedSnapshot = try await store.fetchSnapshot(for: "stage")

        // then
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertNil(deletedSnapshot)
    }

    func test_deleteAll_removesAllSnapshots() async throws {
        // given
        let store = try await makeStore()
        try await seedSnapshots(on: store)

        // when
        try await store.deleteAll()
        let snapshots = try await store.fetchAll()

        // then
        XCTAssertTrue(snapshots.isEmpty)
    }

    func test_makeSessionSnapshotStore_fromContainer_succeeds() async throws {
        // given
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeSessionSnapshotStore()

        // when
        try await store.save(
            SessionSnapshot(
                environment: "prod",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 700),
                userID: "user-prod"
            )
        )
        let snapshots = try await store.fetchAll()

        // then
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.environment, "prod")
        XCTAssertEqual(snapshots.first?.userID, "user-prod")
    }
}

private extension SessionSnapshotStoreTests {
    /// 테스트용 SessionSnapshot store를 생성합니다.
    ///
    /// - Returns:
    /// - in-memory Core Data stack 위에 구성된 SessionSnapshotStore 구현체
    ///
    /// - Throws:
    /// - Core Data stack 초기화에 실패하면 에러를 던집니다.
    func makeStore() async throws -> any SessionSnapshotStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataSessionSnapshotStore(coreDataStack: coreDataStack)
    }

    /// 세션 스냅샷 테스트 데이터 3건을 저장합니다.
    ///
    /// - Parameters:
    ///   - store: 테스트 데이터를 저장할 세션 스냅샷 store
    ///
    /// - Throws:
    /// - 저장 과정에서 오류가 발생하면 에러를 던집니다.
    func seedSnapshots(
        on store: any SessionSnapshotStoreProtocol
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
