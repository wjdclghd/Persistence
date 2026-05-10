//
//  SearchHistoryRecordMapperTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
import CoreData
@testable import Persistence

/// SearchHistoryRecordMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다.
final class SearchHistoryRecordMapperTests: XCTestCase {
    func test_toRecord_withManagedObject_returnsMappedRecord() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SearchHistoryRecordManagedObject(context: context)
        managedObject.keyword = "swiftui"
        managedObject.lastSearchedAt = Date(timeIntervalSince1970: 100)

        // when
        let record = SearchHistoryRecordMapper.toRecord(managedObject)

        // then
        XCTAssertEqual(record.keyword, "swiftui")
        XCTAssertEqual(record.lastSearchedAt, Date(timeIntervalSince1970: 100))
    }

    func test_update_withRecord_updatesManagedObject() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SearchHistoryRecordManagedObject(context: context)
        let record = SearchHistoryRecord(keyword: "combine", lastSearchedAt: Date(timeIntervalSince1970: 200))

        // when
        SearchHistoryRecordMapper.update(managedObject, from: record)

        // then
        XCTAssertEqual(managedObject.keyword, "combine")
        XCTAssertEqual(managedObject.lastSearchedAt, Date(timeIntervalSince1970: 200))
    }

    func test_insert_withRecord_insertsManagedObjectIntoContext() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let record = SearchHistoryRecord(keyword: "swift", lastSearchedAt: Date(timeIntervalSince1970: 300))

        // when
        let managedObject = SearchHistoryRecordMapper.insert(from: record, into: context)

        // then
        XCTAssertEqual(managedObject.keyword, "swift")
        XCTAssertEqual(try context.fetchCount(for: SearchHistoryRecordManagedObject.fetchRequest()), 1)
    }
}
