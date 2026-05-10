//
//  SyncStateRecordMapperTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
import CoreData
@testable import Persistence

/// SyncStateRecordMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다.
final class SyncStateRecordMapperTests: XCTestCase {
    func test_toRecord_withManagedObject_returnsMappedRecord() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SyncStateRecordManagedObject(context: context)
        managedObject.namespace = "prod"
        managedObject.cursor = "cursor-1"
        managedObject.isDirty = true
        managedObject.lastSyncedAt = Date(timeIntervalSince1970: 100)

        // when
        let record = SyncStateRecordMapper.toRecord(managedObject)

        // then
        XCTAssertEqual(record.namespace, "prod")
        XCTAssertEqual(record.cursor, "cursor-1")
        XCTAssertEqual(record.isDirty, true)
        XCTAssertEqual(record.lastSyncedAt, Date(timeIntervalSince1970: 100))
    }

    func test_update_withRecord_updatesManagedObject() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SyncStateRecordManagedObject(context: context)
        let record = SyncStateRecord(
            namespace: "stage",
            cursor: nil,
            isDirty: false,
            lastSyncedAt: Date(timeIntervalSince1970: 200)
        )

        // when
        SyncStateRecordMapper.update(managedObject, from: record)

        // then
        XCTAssertEqual(managedObject.namespace, "stage")
        XCTAssertNil(managedObject.cursor)
        XCTAssertEqual(managedObject.isDirty, false)
        XCTAssertEqual(managedObject.lastSyncedAt, Date(timeIntervalSince1970: 200))
    }

    func test_insert_withRecord_insertsManagedObjectIntoContext() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let record = SyncStateRecord(
            namespace: "dev",
            cursor: "cursor-dev",
            isDirty: true,
            lastSyncedAt: nil
        )

        // when
        let managedObject = SyncStateRecordMapper.insert(from: record, into: context)

        // then
        XCTAssertEqual(managedObject.namespace, "dev")
        XCTAssertEqual(try context.fetchCount(for: SyncStateRecordManagedObject.fetchRequest()), 1)
    }
}
