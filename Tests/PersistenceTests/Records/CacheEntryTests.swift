//
//  CacheEntryTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/// CacheEntry 공개 Record의 값 보관 동작을 검증하는 테스트입니다.
final class CacheEntryTests: XCTestCase {
    func test_init_withAllProperties_storesValues() {
        // given / when
        let entry = CacheEntry(
            namespace: "api",
            key: "home",
            payload: Data("payload".utf8),
            eTag: "etag-1",
            expiresAt: Date(timeIntervalSince1970: 200),
            createdAt: Date(timeIntervalSince1970: 100),
            version: 3
        )

        // then
        XCTAssertEqual(entry.namespace, "api")
        XCTAssertEqual(entry.key, "home")
        XCTAssertEqual(entry.payload, Data("payload".utf8))
        XCTAssertEqual(entry.eTag, "etag-1")
        XCTAssertEqual(entry.expiresAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(entry.createdAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(entry.version, 3)
    }
}
