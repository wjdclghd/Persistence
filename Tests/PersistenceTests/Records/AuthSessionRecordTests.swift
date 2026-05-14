//
//  AuthSessionRecordTests.swift
//  Persistence
//
//  Created by jch on 5/10/26.
//

import Foundation
import XCTest
@testable import Persistence

/// 인증 세션 공개 Record의 값 보관 동작을 검증하는 테스트입니다.
final class AuthSessionRecordTests: XCTestCase {
    func test_init_withAllProperties_storesValues() {
        // given / when
        let record = AuthSessionRecord(
            environment: "prod",
            userID: 1,
            email: "user@example.com",
            nickname: "사용자",
            role: "USER",
            status: "ACTIVE",
            isLoggedIn: true,
            lastRefreshedAt: Date(timeIntervalSince1970: 100)
        )

        // then
        XCTAssertEqual(record.environment, "prod")
        XCTAssertEqual(record.userID, 1)
        XCTAssertEqual(record.email, "user@example.com")
        XCTAssertEqual(record.nickname, "사용자")
        XCTAssertEqual(record.role, "USER")
        XCTAssertEqual(record.status, "ACTIVE")
        XCTAssertEqual(record.isLoggedIn, true)
        XCTAssertEqual(record.lastRefreshedAt, Date(timeIntervalSince1970: 100))
    }
}
