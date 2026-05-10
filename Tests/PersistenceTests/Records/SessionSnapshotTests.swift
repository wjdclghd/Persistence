//
//  SessionSnapshotTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/// 세션 스냅샷 공개 Record의 값 보관 동작을 검증하는 테스트입니다.
final class SessionSnapshotTests: XCTestCase {
    func test_init_withAllProperties_storesValues() {
        // given / when
        let snapshot = SessionSnapshot(
            environment: "prod",
            isLoggedIn: true,
            lastRefreshedAt: Date(timeIntervalSince1970: 200),
            userID: "user-1"
        )

        // then
        XCTAssertEqual(snapshot.environment, "prod")
        XCTAssertEqual(snapshot.isLoggedIn, true)
        XCTAssertEqual(snapshot.lastRefreshedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(snapshot.userID, "user-1")
    }
}
