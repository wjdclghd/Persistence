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

/* SearchHistoryRecordMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다. */
final class SearchHistoryRecordMapperTests: XCTestCase {
    /* ManagedObject가 API 모델로 정확히 변환되는지 검증합니다. */
    func test_toRecord_returnsMappedRecord() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SearchHistoryRecordMO(context: context)
        managedObject.keyword = "swiftui"
        managedObject.lastSearchedAt = Date(timeIntervalSince1970: 100)

        let record = SearchHistoryRecordMapper.toRecord(managedObject)

        XCTAssertEqual(record.keyword, "swiftui")
        XCTAssertEqual(record.lastSearchedAt, Date(timeIntervalSince1970: 100))
    }

    /* API 모델 값이 기존 ManagedObject에 반영되는지 검증합니다. */
    func test_update_updatesManagedObject() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SearchHistoryRecordMO(context: context)
        let record = SearchHistoryRecord(keyword: "combine", lastSearchedAt: Date(timeIntervalSince1970: 200))

        SearchHistoryRecordMapper.update(managedObject, from: record)

        XCTAssertEqual(managedObject.keyword, "combine")
        XCTAssertEqual(managedObject.lastSearchedAt, Date(timeIntervalSince1970: 200))
    }

    /* API 모델 값으로 새 ManagedObject가 삽입되는지 검증합니다. */
    func test_insert_insertsManagedObjectIntoContext() throws {
        let context = try InMemoryManagedObjectContext.make()
        let record = SearchHistoryRecord(keyword: "swift", lastSearchedAt: Date(timeIntervalSince1970: 300))

        let managedObject = SearchHistoryRecordMapper.insert(from: record, into: context)

        XCTAssertEqual(managedObject.keyword, "swift")
        XCTAssertEqual(try context.fetchCount(for: SearchHistoryRecordMO.fetchRequest()), 1)
    }
}
