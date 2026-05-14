//
//  AuthSessionRecordMapperTests.swift
//  Persistence
//
//  Created by jch on 5/10/26.
//

import Foundation
import XCTest
import CoreData
@testable import Persistence

/// AuthSessionRecordMapper의 변환, 갱신, 삽입 동작을 검증하는 테스트입니다.
final class AuthSessionRecordMapperTests: XCTestCase {
    func test_toRecord_withManagedObject_returnsMappedRecord() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = AuthSessionRecordManagedObject(context: context)
        managedObject.environment = "prod"
        managedObject.userID = 10
        managedObject.email = "user@example.com"
        managedObject.nickname = "사용자"
        managedObject.role = "USER"
        managedObject.status = "ACTIVE"
        managedObject.isLoggedIn = true
        managedObject.lastRefreshedAt = Date(timeIntervalSince1970: 100)

        // when
        let record = AuthSessionRecordMapper.toRecord(managedObject)

        // then
        XCTAssertEqual(record.environment, "prod")
        XCTAssertEqual(record.userID, 10)
        XCTAssertEqual(record.email, "user@example.com")
        XCTAssertEqual(record.nickname, "사용자")
        XCTAssertEqual(record.role, "USER")
        XCTAssertEqual(record.status, "ACTIVE")
        XCTAssertEqual(record.isLoggedIn, true)
        XCTAssertEqual(record.lastRefreshedAt, Date(timeIntervalSince1970: 100))
    }

    func test_update_withRecord_updatesManagedObject() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let managedObject = AuthSessionRecordManagedObject(context: context)
        let record = AuthSessionRecord(
            environment: "stage",
            userID: 20,
            email: "stage@example.com",
            nickname: "스테이지",
            role: "ADMIN",
            status: "ACTIVE",
            isLoggedIn: true,
            lastRefreshedAt: Date(timeIntervalSince1970: 200)
        )

        // when
        AuthSessionRecordMapper.update(managedObject, from: record)

        // then
        XCTAssertEqual(managedObject.environment, "stage")
        XCTAssertEqual(managedObject.userID, 20)
        XCTAssertEqual(managedObject.email, "stage@example.com")
        XCTAssertEqual(managedObject.nickname, "스테이지")
        XCTAssertEqual(managedObject.role, "ADMIN")
        XCTAssertEqual(managedObject.status, "ACTIVE")
        XCTAssertEqual(managedObject.isLoggedIn, true)
        XCTAssertEqual(managedObject.lastRefreshedAt, Date(timeIntervalSince1970: 200))
    }

    func test_insert_withRecord_insertsManagedObjectIntoContext() throws {
        // given
        let context = try InMemoryManagedObjectContext.make()
        let record = AuthSessionRecord(
            environment: "dev",
            userID: 30,
            email: "dev@example.com",
            nickname: "개발",
            role: "USER",
            status: "ACTIVE",
            isLoggedIn: true,
            lastRefreshedAt: Date(timeIntervalSince1970: 300)
        )

        // when
        let managedObject = AuthSessionRecordMapper.insert(from: record, into: context)

        // then
        XCTAssertEqual(managedObject.environment, "dev")
        XCTAssertEqual(try context.fetchCount(for: AuthSessionRecordManagedObject.fetchRequest()), 1)
    }
}
