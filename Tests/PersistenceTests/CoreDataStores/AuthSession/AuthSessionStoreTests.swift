//
//  AuthSessionStoreTests.swift
//  Persistence
//
//  Created by jch on 5/10/26.
//

import Foundation
import XCTest
@testable import Persistence

/// AuthSessionStore 구현의 조회, 저장, 삭제 동작을 검증하는 테스트입니다.
final class AuthSessionStoreTests: XCTestCase {
    func test_fetchAll_returnsSessionsSortedByEnvironmentAscending() async throws {
        // given
        let store = try await makeStore()
        try await store.save(makeRecord(environment: "prod", userID: 3))
        try await store.save(makeRecord(environment: "dev", userID: 1))
        try await store.save(makeRecord(environment: "stage", userID: 2))

        // when
        let sessions = try await store.fetchAll()

        // then
        XCTAssertEqual(sessions.map(\.environment), ["dev", "prod", "stage"])
    }

    func test_save_withExistingEnvironment_updatesExistingSession() async throws {
        // given
        let store = try await makeStore()
        try await store.save(
            makeRecord(
                environment: "prod",
                userID: 1,
                email: "old@example.com",
                nickname: "기존",
                role: "USER",
                status: "ACTIVE",
                lastRefreshedAt: Date(timeIntervalSince1970: 100)
            )
        )

        // when
        try await store.save(
            makeRecord(
                environment: "prod",
                userID: 2,
                email: "new@example.com",
                nickname: "갱신",
                role: "ADMIN",
                status: "LOCKED",
                lastRefreshedAt: Date(timeIntervalSince1970: 200)
            )
        )
        let sessions = try await store.fetchAll()

        // then
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.environment, "prod")
        XCTAssertEqual(sessions.first?.userID, 2)
        XCTAssertEqual(sessions.first?.email, "new@example.com")
        XCTAssertEqual(sessions.first?.nickname, "갱신")
        XCTAssertEqual(sessions.first?.role, "ADMIN")
        XCTAssertEqual(sessions.first?.status, "LOCKED")
        XCTAssertEqual(sessions.first?.lastRefreshedAt, Date(timeIntervalSince1970: 200))
    }

    func test_fetchSession_returnsMatchingSession() async throws {
        // given
        let store = try await makeStore()
        try await seedSessions(on: store)

        // when
        let session = try await store.fetchSession(for: "stage")

        // then
        XCTAssertEqual(session?.environment, "stage")
        XCTAssertEqual(session?.userID, 2)
        XCTAssertEqual(session?.email, "stage@example.com")
        XCTAssertEqual(session?.nickname, "스테이지")
        XCTAssertEqual(session?.role, "USER")
        XCTAssertEqual(session?.status, "ACTIVE")
        XCTAssertEqual(session?.isLoggedIn, true)
        XCTAssertEqual(session?.lastRefreshedAt, Date(timeIntervalSince1970: 200))
    }

    func test_fetchSession_withBlankEnvironment_returnsNil() async throws {
        // given
        let store = try await makeStore()
        try await seedSessions(on: store)

        // when
        let session = try await store.fetchSession(for: "   ")

        // then
        XCTAssertNil(session)
    }

    func test_save_trimsRequiredStringFields() async throws {
        // given
        let store = try await makeStore()

        // when
        try await store.save(
            AuthSessionRecord(
                environment: " prod ",
                userID: 10,
                email: " user@example.com ",
                nickname: " 사용자 ",
                role: " USER ",
                status: " ACTIVE ",
                isLoggedIn: true,
                lastRefreshedAt: Date(timeIntervalSince1970: 100)
            )
        )
        let session = try await store.fetchSession(for: "prod")

        // then
        XCTAssertEqual(session?.environment, "prod")
        XCTAssertEqual(session?.email, "user@example.com")
        XCTAssertEqual(session?.nickname, "사용자")
        XCTAssertEqual(session?.role, "USER")
        XCTAssertEqual(session?.status, "ACTIVE")
    }

    func test_save_withBlankEnvironment_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()
        let record = makeRecord(environment: "   ")

        // when / then
        try await assertSaveThrowsWriteFailed(record, on: store)
    }

    func test_save_withBlankEmail_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()
        let record = makeRecord(email: "   ")

        // when / then
        try await assertSaveThrowsWriteFailed(record, on: store)
    }

    func test_save_withBlankNickname_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()
        let record = makeRecord(nickname: "   ")

        // when / then
        try await assertSaveThrowsWriteFailed(record, on: store)
    }

    func test_save_withBlankRole_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()
        let record = makeRecord(role: "   ")

        // when / then
        try await assertSaveThrowsWriteFailed(record, on: store)
    }

    func test_save_withBlankStatus_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()
        let record = makeRecord(status: "   ")

        // when / then
        try await assertSaveThrowsWriteFailed(record, on: store)
    }

    func test_save_withInvalidUserID_throwsWriteFailed() async throws {
        // given
        let store = try await makeStore()
        let record = makeRecord(userID: 0)

        // when / then
        try await assertSaveThrowsWriteFailed(record, on: store)
    }

    func test_delete_removesOnlyMatchingSession() async throws {
        // given
        let store = try await makeStore()
        try await seedSessions(on: store)

        // when
        try await store.delete(environment: " stage ")
        let sessions = try await store.fetchAll()
        let deletedSession = try await store.fetchSession(for: "stage")

        // then
        XCTAssertEqual(sessions.count, 2)
        XCTAssertNil(deletedSession)
    }

    func test_deleteAll_removesAllSessions() async throws {
        // given
        let store = try await makeStore()
        try await seedSessions(on: store)

        // when
        try await store.deleteAll()
        let sessions = try await store.fetchAll()

        // then
        XCTAssertTrue(sessions.isEmpty)
    }

    func test_makeAuthSessionStore_fromContainer_succeeds() async throws {
        // given
        let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
        let store = container.makeAuthSessionStore()

        // when
        try await store.save(
            makeRecord(
                environment: "prod",
                userID: 700,
                email: "prod@example.com",
                lastRefreshedAt: Date(timeIntervalSince1970: 700)
            )
        )
        let session = try await store.fetchSession(for: "prod")

        // then
        XCTAssertEqual(session?.environment, "prod")
        XCTAssertEqual(session?.userID, 700)
        XCTAssertEqual(session?.email, "prod@example.com")
    }
}

private extension AuthSessionStoreTests {
    func makeStore() async throws -> any AuthSessionStoreProtocol {
        let coreDataStack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        return CoreDataAuthSessionStore(coreDataStack: coreDataStack)
    }

    func seedSessions(
        on store: any AuthSessionStoreProtocol
    ) async throws {
        try await store.save(
            makeRecord(
                environment: "prod",
                userID: 3,
                email: "prod@example.com",
                nickname: "프로덕션",
                lastRefreshedAt: Date(timeIntervalSince1970: 300)
            )
        )
        try await store.save(
            makeRecord(
                environment: "dev",
                userID: 1,
                email: "dev@example.com",
                nickname: "개발",
                lastRefreshedAt: Date(timeIntervalSince1970: 100)
            )
        )
        try await store.save(
            makeRecord(
                environment: "stage",
                userID: 2,
                email: "stage@example.com",
                nickname: "스테이지",
                lastRefreshedAt: Date(timeIntervalSince1970: 200)
            )
        )
    }

    func makeRecord(
        environment: String = "prod",
        userID: Int64 = 1,
        email: String = "user@example.com",
        nickname: String = "사용자",
        role: String = "USER",
        status: String = "ACTIVE",
        isLoggedIn: Bool = true,
        lastRefreshedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> AuthSessionRecord {
        AuthSessionRecord(
            environment: environment,
            userID: userID,
            email: email,
            nickname: nickname,
            role: role,
            status: status,
            isLoggedIn: isLoggedIn,
            lastRefreshedAt: lastRefreshedAt
        )
    }

    func assertSaveThrowsWriteFailed(
        _ record: AuthSessionRecord,
        on store: any AuthSessionStoreProtocol
    ) async throws {
        do {
            try await store.save(record)
            XCTFail("Expected writeFailed error")
        } catch let error as PersistenceError {
            guard case let .writeFailed(message) = error else {
                return XCTFail("Expected writeFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }
}
