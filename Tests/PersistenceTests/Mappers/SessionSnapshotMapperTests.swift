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

/// SessionSnapshotMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다.
final class SessionSnapshotMapperTests: XCTestCase {
    func test_toSnapshot_withManagedObject_returnsMappedSnapshot() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SessionSnapshotManagedObject(context: context)
        managedObject.environment = "prod"
        managedObject.isLoggedIn = true
        managedObject.lastRefreshedAt = Date(timeIntervalSince1970: 100)
        managedObject.userID = "user-1"

        // when
        let snapshot = SessionSnapshotMapper.toSnapshot(managedObject)

        // then
        XCTAssertEqual(snapshot.environment, "prod")
        XCTAssertEqual(snapshot.isLoggedIn, true)
        XCTAssertEqual(snapshot.lastRefreshedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(snapshot.userID, "user-1")
    }

    func test_update_withSnapshot_updatesManagedObject() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = SessionSnapshotManagedObject(context: context)
        let snapshot = SessionSnapshot(
            environment: "stage",
            isLoggedIn: false,
            lastRefreshedAt: Date(timeIntervalSince1970: 200),
            userID: nil
        )

        // when
        SessionSnapshotMapper.update(managedObject, from: snapshot)

        // then
        XCTAssertEqual(managedObject.environment, "stage")
        XCTAssertEqual(managedObject.isLoggedIn, false)
        XCTAssertEqual(managedObject.lastRefreshedAt, Date(timeIntervalSince1970: 200))
        XCTAssertNil(managedObject.userID)
    }

    func test_insert_withSnapshot_insertsManagedObjectIntoContext() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let snapshot = SessionSnapshot(
            environment: "dev",
            isLoggedIn: true,
            lastRefreshedAt: nil,
            userID: "user-dev"
        )

        // when
        let managedObject = SessionSnapshotMapper.insert(from: snapshot, into: context)

        // then
        XCTAssertEqual(managedObject.environment, "dev")
        XCTAssertEqual(try context.fetchCount(for: SessionSnapshotManagedObject.fetchRequest()), 1)
    }
}
