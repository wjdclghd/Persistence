//
//  FavoriteRecordMapperTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
import CoreData
@testable import Persistence

/// FavoriteRecordMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다.
final class FavoriteRecordMapperTests: XCTestCase {
    func test_toRecord_withManagedObject_returnsMappedRecord() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = FavoriteRecordManagedObject(context: context)
        managedObject.id = "hotel-1"
        managedObject.type = "hotel"
        managedObject.createdAt = Date(timeIntervalSince1970: 100)

        // when
        let record = FavoriteRecordMapper.toRecord(managedObject)

        // then
        XCTAssertEqual(record.id, "hotel-1")
        XCTAssertEqual(record.type, "hotel")
        XCTAssertEqual(record.createdAt, Date(timeIntervalSince1970: 100))
    }

    func test_update_withRecord_updatesManagedObject() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = FavoriteRecordManagedObject(context: context)
        let record = FavoriteRecord(id: "place-1", type: "place", createdAt: Date(timeIntervalSince1970: 200))

        // when
        FavoriteRecordMapper.update(managedObject, from: record)

        // then
        XCTAssertEqual(managedObject.id, "place-1")
        XCTAssertEqual(managedObject.type, "place")
        XCTAssertEqual(managedObject.createdAt, Date(timeIntervalSince1970: 200))
    }

    func test_insert_withRecord_insertsManagedObjectIntoContext() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let record = FavoriteRecord(id: "hotel-1", type: "hotel", createdAt: Date(timeIntervalSince1970: 300))

        // when
        let managedObject = FavoriteRecordMapper.insert(from: record, into: context)

        // then
        XCTAssertEqual(managedObject.id, "hotel-1")
        XCTAssertEqual(managedObject.type, "hotel")
        XCTAssertEqual(try context.fetchCount(for: FavoriteRecordManagedObject.fetchRequest()), 1)
    }
}
