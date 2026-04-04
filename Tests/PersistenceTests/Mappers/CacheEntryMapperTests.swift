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

/* CacheEntryMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다. */
final class CacheEntryMapperTests: XCTestCase {
    /* ManagedObject가 API 모델로 정확히 변환되는지 검증합니다. */
    func test_toEntry_returnsMappedEntry() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = CacheEntryMO(context: context)
        managedObject.namespace = "api"
        managedObject.key = "home"
        managedObject.payload = Data("payload".utf8)
        managedObject.eTag = "etag-1"
        managedObject.expiresAt = Date(timeIntervalSince1970: 200)
        managedObject.createdAt = Date(timeIntervalSince1970: 100)
        managedObject.version = 3

        let entry = CacheEntryMapper.toEntry(managedObject)

        XCTAssertEqual(entry.namespace, "api")
        XCTAssertEqual(entry.key, "home")
        XCTAssertEqual(entry.payload, Data("payload".utf8))
        XCTAssertEqual(entry.eTag, "etag-1")
        XCTAssertEqual(entry.expiresAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(entry.createdAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(entry.version, 3)
    }

    /* API 모델 값이 기존 ManagedObject에 반영되는지 검증합니다. */
    func test_update_updatesManagedObject() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = CacheEntryMO(context: context)
        let entry = CacheEntry(namespace: "image", key: "banner", payload: Data("v2".utf8), eTag: nil, expiresAt: nil, createdAt: Date(timeIntervalSince1970: 500), version: 5)

        CacheEntryMapper.update(managedObject, from: entry)

        XCTAssertEqual(managedObject.namespace, "image")
        XCTAssertEqual(managedObject.key, "banner")
        XCTAssertEqual(managedObject.payload, Data("v2".utf8))
        XCTAssertNil(managedObject.eTag)
        XCTAssertNil(managedObject.expiresAt)
        XCTAssertEqual(managedObject.createdAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(managedObject.version, 5)
    }

    /* API 모델 값으로 새 ManagedObject가 삽입되는지 검증합니다. */
    func test_insert_insertsManagedObjectIntoContext() throws {
        let context = try InMemoryManagedObjectContext.make()
        let entry = CacheEntry(namespace: "api", key: "home", payload: Data("payload".utf8), eTag: "etag-2", expiresAt: Date(timeIntervalSince1970: 600), createdAt: Date(timeIntervalSince1970: 400), version: 7)

        let managedObject = CacheEntryMapper.insert(from: entry, into: context)

        XCTAssertEqual(managedObject.namespace, "api")
        XCTAssertEqual(managedObject.key, "home")
        XCTAssertEqual(try context.fetchCount(for: CacheEntryMO.fetchRequest()), 1)
    }
}
