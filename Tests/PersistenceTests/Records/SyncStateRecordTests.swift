//
//  SyncStateRecordTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/// 동기화 상태 공개 Record의 값 보관 동작을 검증하는 테스트입니다.
final class SyncStateRecordTests: XCTestCase {
    func test_init_withAllProperties_storesValues() {
        // given / when
        let record = SyncStateRecord(
            namespace: "prod",
            cursor: "cursor-1",
            isDirty: true,
            lastSyncedAt: Date(timeIntervalSince1970: 300)
        )

        // then
        XCTAssertEqual(record.namespace, "prod")
        XCTAssertEqual(record.cursor, "cursor-1")
        XCTAssertEqual(record.isDirty, true)
        XCTAssertEqual(record.lastSyncedAt, Date(timeIntervalSince1970: 300))
    }
}
