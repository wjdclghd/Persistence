//
//  FavoriteRecordTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/// 즐겨찾기 공개 Record의 값 보관 동작을 검증하는 테스트입니다.
final class FavoriteRecordTests: XCTestCase {
    func test_init_withAllProperties_storesValues() {
        // given / when
        let record = FavoriteRecord(
            id: "hotel-1",
            type: "hotel",
            createdAt: Date(timeIntervalSince1970: 100)
        )

        // then
        XCTAssertEqual(record.id, "hotel-1")
        XCTAssertEqual(record.type, "hotel")
        XCTAssertEqual(record.createdAt, Date(timeIntervalSince1970: 100))
    }
}
