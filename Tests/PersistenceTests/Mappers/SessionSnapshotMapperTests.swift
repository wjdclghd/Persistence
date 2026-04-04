//
//  SessionSnapshotMapperTests.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import XCTest
import CoreData
@testable import Persistence

/* SessionSnapshotMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다. */
final class SessionSnapshotMapperTests: XCTestCase {
    /* ManagedObject가 API 모델로 정확히 변환되는지 검증합니다. */
    func test_toSnapshot_returnsMappedSnapshot() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SessionSnapshotMO(context: context)
        managedObject.environment = "prod"
        managedObject.isLoggedIn = true
        managedObject.lastRefreshedAt = Date(timeIntervalSince1970: 100)
        managedObject.userID = "user-1"

        let snapshot = SessionSnapshotMapper.toSnapshot(managedObject)

        XCTAssertEqual(snapshot.environment, "prod")
        XCTAssertEqual(snapshot.isLoggedIn, true)
        XCTAssertEqual(snapshot.lastRefreshedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(snapshot.userID, "user-1")
    }

    /* API 모델 값이 기존 ManagedObject에 반영되는지 검증합니다. */
    func test_update_updatesManagedObject() throws {
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SessionSnapshotMO(context: context)
        let snapshot = SessionSnapshot(environment: "stage", isLoggedIn: false, lastRefreshedAt: Date(timeIntervalSince1970: 200), userID: nil)

        SessionSnapshotMapper.update(managedObject, from: snapshot)

        XCTAssertEqual(managedObject.environment, "stage")
        XCTAssertEqual(managedObject.isLoggedIn, false)
        XCTAssertEqual(managedObject.lastRefreshedAt, Date(timeIntervalSince1970: 200))
        XCTAssertNil(managedObject.userID)
    }

    /* API 모델 값으로 새 ManagedObject가 삽입되는지 검증합니다. */
    func test_insert_insertsManagedObjectIntoContext() throws {
        let context = try InMemoryManagedObjectContext.make()
        let snapshot = SessionSnapshot(environment: "dev", isLoggedIn: true, lastRefreshedAt: nil, userID: "user-dev")

        let managedObject = SessionSnapshotMapper.insert(from: snapshot, into: context)

        XCTAssertEqual(managedObject.environment, "dev")
        XCTAssertEqual(try context.fetchCount(for: SessionSnapshotMO.fetchRequest()), 1)
    }
}
