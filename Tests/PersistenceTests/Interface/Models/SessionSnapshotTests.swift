//
//  SessionSnapshotTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/* 세션 스냅샷 API 모델의 값 보관 동작을 검증하는 테스트입니다. */
final class SessionSnapshotTests: XCTestCase {
    /* 전달한 초기값이 그대로 저장되는지 검증합니다. */
    func test_init_storesAllProperties() {
        let snapshot = SessionSnapshot(
            environment: "prod",
            isLoggedIn: true,
            lastRefreshedAt: Date(timeIntervalSince1970: 200),
            userID: "user-1"
        )

        XCTAssertEqual(snapshot.environment, "prod")
        XCTAssertEqual(snapshot.isLoggedIn, true)
        XCTAssertEqual(snapshot.lastRefreshedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(snapshot.userID, "user-1")
    }
}
