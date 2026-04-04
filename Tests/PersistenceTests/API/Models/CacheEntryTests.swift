//
//  CacheEntryTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
@testable import Persistence

/*
 CacheEntry API 모델의 값 보관 동작을 검증하는 테스트입니다.

 CacheEntry는 Persistence 외부와 데이터를 주고받는 값 객체이므로,
 초기화 시 전달한 값이 그대로 유지되는지 확인합니다.
 */
final class CacheEntryTests: XCTestCase {
    /* 전달한 초기값이 모든 프로퍼티에 그대로 저장되는지 검증합니다. */
    func test_init_storesAllProperties() {
        let entry = CacheEntry(
            namespace: "api",
            key: "home",
            payload: Data("payload".utf8),
            eTag: "etag-1",
            expiresAt: Date(timeIntervalSince1970: 200),
            createdAt: Date(timeIntervalSince1970: 100),
            version: 3
        )

        XCTAssertEqual(entry.namespace, "api")
        XCTAssertEqual(entry.key, "home")
        XCTAssertEqual(entry.payload, Data("payload".utf8))
        XCTAssertEqual(entry.eTag, "etag-1")
        XCTAssertEqual(entry.expiresAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(entry.createdAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(entry.version, 3)
    }
}
