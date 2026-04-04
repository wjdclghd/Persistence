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

/* SyncStateRecordMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다. */
final class SyncStateRecordMapperTests: XCTestCase {
    /* ManagedObject가 API 모델로 정확히 변환되는지 검증합니다. */
    func test_toRecord_returnsMappedRecord() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SyncStateRecordMO(context: context)
        managedObject.namespace = "prod"
        managedObject.cursor = "cursor-1"
        managedObject.isDirty = true
        managedObject.lastSyncedAt = Date(timeIntervalSince1970: 100)

        let record = SyncStateRecordMapper.toRecord(managedObject)

        XCTAssertEqual(record.namespace, "prod")
        XCTAssertEqual(record.cursor, "cursor-1")
        XCTAssertEqual(record.isDirty, true)
        XCTAssertEqual(record.lastSyncedAt, Date(timeIntervalSince1970: 100))
    }

    /* API 모델 값이 기존 ManagedObject에 반영되는지 검증합니다. */
    func test_update_updatesManagedObject() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SyncStateRecordMO(context: context)
        let record = SyncStateRecord(namespace: "stage", cursor: nil, isDirty: false, lastSyncedAt: Date(timeIntervalSince1970: 200))

        SyncStateRecordMapper.update(managedObject, from: record)

        XCTAssertEqual(managedObject.namespace, "stage")
        XCTAssertNil(managedObject.cursor)
        XCTAssertEqual(managedObject.isDirty, false)
        XCTAssertEqual(managedObject.lastSyncedAt, Date(timeIntervalSince1970: 200))
    }

    /* API 모델 값으로 새 ManagedObject가 삽입되는지 검증합니다. */
    func test_insert_insertsManagedObjectIntoContext() throws {
        let context = try InMemoryManagedObjectContext.make()
        let record = SyncStateRecord(namespace: "dev", cursor: "cursor-dev", isDirty: true, lastSyncedAt: nil)

        let managedObject = SyncStateRecordMapper.insert(from: record, into: context)

        XCTAssertEqual(managedObject.namespace, "dev")
        XCTAssertEqual(try context.fetchCount(for: SyncStateRecordMO.fetchRequest()), 1)
    }
}
