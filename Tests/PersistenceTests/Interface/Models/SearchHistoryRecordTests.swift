//
//  SearchHistoryRecordTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/* 검색 기록 API 모델의 값 보관 동작을 검증하는 테스트입니다. */
final class SearchHistoryRecordTests: XCTestCase {
    /* 전달한 초기값이 그대로 저장되는지 검증합니다. */
    func test_init_storesAllProperties() {
        let record = SearchHistoryRecord(
            keyword: "swiftui",
            lastSearchedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(record.keyword, "swiftui")
        XCTAssertEqual(record.lastSearchedAt, Date(timeIntervalSince1970: 100))
    }
}
