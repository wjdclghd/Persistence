//
//  CacheEntryMapperTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import CoreData
import XCTest
@testable import Persistence

/// CacheEntryMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다.
final class CacheEntryMapperTests: XCTestCase {
    func test_toEntry_withManagedObject_returnsMappedEntry() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = CacheEntryManagedObject(context: context)
        managedObject.namespace = "api"
        managedObject.key = "home"
        managedObject.payload = Data("payload".utf8)
        managedObject.eTag = "etag-1"
        managedObject.expiresAt = Date(timeIntervalSince1970: 200)
        managedObject.createdAt = Date(timeIntervalSince1970: 100)
        managedObject.version = 3

        // when
        let entry = CacheEntryMapper.toEntry(managedObject)

        // then
        XCTAssertEqual(entry.namespace, "api")
        XCTAssertEqual(entry.key, "home")
        XCTAssertEqual(entry.payload, Data("payload".utf8))
        XCTAssertEqual(entry.eTag, "etag-1")
        XCTAssertEqual(entry.expiresAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(entry.createdAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(entry.version, 3)
    }

    func test_update_withEntry_updatesManagedObject() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = CacheEntryManagedObject(context: context)
        let entry = CacheEntry(
            namespace: "image",
            key: "banner",
            payload: Data("v2".utf8),
            eTag: nil,
            expiresAt: nil,
            createdAt: Date(timeIntervalSince1970: 500),
            version: 5
        )

        // when
        CacheEntryMapper.update(managedObject, from: entry)

        // then
        XCTAssertEqual(managedObject.namespace, "image")
        XCTAssertEqual(managedObject.key, "banner")
        XCTAssertEqual(managedObject.payload, Data("v2".utf8))
        XCTAssertNil(managedObject.eTag)
        XCTAssertNil(managedObject.expiresAt)
        XCTAssertEqual(managedObject.createdAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(managedObject.version, 5)
    }

    func test_insert_withEntry_insertsManagedObjectIntoContext() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let entry = CacheEntry(
            namespace: "api",
            key: "home",
            payload: Data("payload".utf8),
            eTag: "etag-2",
            expiresAt: Date(timeIntervalSince1970: 600),
            createdAt: Date(timeIntervalSince1970: 400),
            version: 7
        )

        // when
        let managedObject = CacheEntryMapper.insert(from: entry, into: context)

        // then
        XCTAssertEqual(managedObject.namespace, "api")
        XCTAssertEqual(managedObject.key, "home")
        XCTAssertEqual(try context.fetchCount(for: CacheEntryManagedObject.fetchRequest()), 1)
    }
}
