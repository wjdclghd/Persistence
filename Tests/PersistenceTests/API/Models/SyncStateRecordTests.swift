//
//  SyncStateRecordTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/* 동기화 상태 API 모델의 값 보관 동작을 검증하는 테스트입니다. */
final class SyncStateRecordTests: XCTestCase {
    /* 전달한 초기값이 그대로 저장되는지 검증합니다. */
    func test_init_storesAllProperties() {
        let record = SyncStateRecord(
            namespace: "prod",
            cursor: "cursor-1",
            isDirty: true,
            lastSyncedAt: Date(timeIntervalSince1970: 300)
        )

        XCTAssertEqual(record.namespace, "prod")
        XCTAssertEqual(record.cursor, "cursor-1")
        XCTAssertEqual(record.isDirty, true)
        XCTAssertEqual(record.lastSyncedAt, Date(timeIntervalSince1970: 300))
    }
}
