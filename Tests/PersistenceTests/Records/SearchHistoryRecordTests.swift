//
//  SearchHistoryRecordTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/// 검색 기록 공개 Record의 값 보관 동작을 검증하는 테스트입니다.
final class SearchHistoryRecordTests: XCTestCase {
    func test_init_withAllProperties_storesValues() {
        // given / when
        let record = SearchHistoryRecord(
            keyword: "swiftui",
            lastSearchedAt: Date(timeIntervalSince1970: 100)
        )

        // then
        XCTAssertEqual(record.keyword, "swiftui")
        XCTAssertEqual(record.lastSearchedAt, Date(timeIntervalSince1970: 100))
    }
}
