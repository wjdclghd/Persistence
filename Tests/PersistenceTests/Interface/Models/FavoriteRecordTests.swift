//
//  FavoriteRecordTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/* 즐겨찾기 API 모델의 값 보관 동작을 검증하는 테스트입니다. */
final class FavoriteRecordTests: XCTestCase {
    /* 전달한 초기값이 그대로 저장되는지 검증합니다. */
    func test_init_storesAllProperties() {
        let record = FavoriteRecord(
            id: "hotel-1",
            type: "hotel",
            createdAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(record.id, "hotel-1")
        XCTAssertEqual(record.type, "hotel")
        XCTAssertEqual(record.createdAt, Date(timeIntervalSince1970: 100))
    }
}
