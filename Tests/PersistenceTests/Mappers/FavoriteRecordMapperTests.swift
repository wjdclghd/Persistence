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

/* FavoriteRecordMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다. */
final class FavoriteRecordMapperTests: XCTestCase {
    /* ManagedObject가 API 모델로 정확히 변환되는지 검증합니다. */
    func test_toRecord_returnsMappedRecord() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = FavoriteRecordMO(context: context)
        managedObject.id = "hotel-1"
        managedObject.type = "hotel"
        managedObject.createdAt = Date(timeIntervalSince1970: 100)

        let record = FavoriteRecordMapper.toRecord(managedObject)

        XCTAssertEqual(record.id, "hotel-1")
        XCTAssertEqual(record.type, "hotel")
        XCTAssertEqual(record.createdAt, Date(timeIntervalSince1970: 100))
    }

    /* API 모델 값이 기존 ManagedObject에 반영되는지 검증합니다. */
    func test_update_updatesManagedObject() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = FavoriteRecordMO(context: context)
        let record = FavoriteRecord(id: "place-1", type: "place", createdAt: Date(timeIntervalSince1970: 200))

        FavoriteRecordMapper.update(managedObject, from: record)

        XCTAssertEqual(managedObject.id, "place-1")
        XCTAssertEqual(managedObject.type, "place")
        XCTAssertEqual(managedObject.createdAt, Date(timeIntervalSince1970: 200))
    }

    /* API 모델 값으로 새 ManagedObject가 삽입되는지 검증합니다. */
    func test_insert_insertsManagedObjectIntoContext() throws {
        let context = try InMemoryManagedObjectContext.make()
        let record = FavoriteRecord(id: "hotel-1", type: "hotel", createdAt: Date(timeIntervalSince1970: 300))

        let managedObject = FavoriteRecordMapper.insert(from: record, into: context)

        XCTAssertEqual(managedObject.id, "hotel-1")
        XCTAssertEqual(managedObject.type, "hotel")
        XCTAssertEqual(try context.fetchCount(for: FavoriteRecordMO.fetchRequest()), 1)
    }
}
