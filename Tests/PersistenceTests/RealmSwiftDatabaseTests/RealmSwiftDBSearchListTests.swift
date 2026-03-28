//
//  RealmSwiftDBSearchListTests.swift
//  CoreDatabaseTests
//
//  Created by jch on 7/1/25.
//
/*
import Foundation
import XCTest
import Combine
import RealmSwift
@testable import CoreDatabase

private struct TestSearchListEntity: Codable, RealmSwiftDBSearchListEntityProtocol {
    let searchKeyword: String
    
    init(searchKeyword: String) {
        self.searchKeyword = searchKeyword
    }
}

final class RealmSwiftDBSearchListTests: XCTestCase {
    private var testRealmSwiftDBSearchList: RealmSwiftDBSearchList!
    
    private var testCancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        var testConfig = Realm.Configuration(inMemoryIdentifier: self.name)
        testConfig.schemaVersion = RealmSwiftDBMigration.currentSchemaVersion
        testConfig.migrationBlock = RealmSwiftDBMigration.migrationBlock
        
        let testRealm = try Realm(configuration: testConfig)
        testRealmSwiftDBSearchList = RealmSwiftDBSearchList(realmDatabase: testRealm)
        
        testCancellables = []
    }

    override func tearDownWithError() throws {
        testRealmSwiftDBSearchList = nil
        
        testCancellables = nil
    }

    func testInsertAndSelect() {
        let testExpectation = expectation(description: "TestInsert & TestSelect")
        let testEntity = TestSearchListEntity(searchKeyword: "TestKeyword")

        testRealmSwiftDBSearchList.insertDatabase(searchListEntity: testEntity)
            .flatMap { [unowned self] _ in
                self.testRealmSwiftDBSearchList.selectDatabase(searchKeyword: "TestKeyword") as AnyPublisher<[TestSearchListEntity], Error>
            }
            .sink(
                receiveCompletion: { testCompletion in
                    if case .failure(let testError) = testCompletion {
                        XCTFail("에러 발생: \(testError)")
                    }
                },
                receiveValue: { testResult in
                    XCTAssertEqual(testResult.count, 1)
                    XCTAssertEqual(testResult.first?.searchKeyword, "TestKeyword")
                    
                    testExpectation.fulfill()
                }
            )
            .store(in: &testCancellables)

        wait(for: [testExpectation], timeout: 1.0)
    }

    func testUpdateDatabase() {
        let testExpectation = expectation(description: "TestUpdateDatabase")
        let testEntity = TestSearchListEntity(searchKeyword: "TestKeyword")
        
        testRealmSwiftDBSearchList.insertDatabase(searchListEntity: testEntity)
            .flatMap { [unowned self] _ in
                self.testRealmSwiftDBSearchList.updateDatabase(searchListEntity: testEntity)
            }
            .sink(
                receiveCompletion: { testCompletion in
                    if case .failure(let testError) = testCompletion {
                        XCTFail("업데이트 실패: \(testError)")
                    }
                },
                receiveValue: { testResult in
                    XCTAssertEqual(testResult.count, 1)
                    XCTAssertEqual(testResult.first?.searchKeyword, "TestKeyword")
                    
                    testExpectation.fulfill()
                }
            )
            .store(in: &testCancellables)

        wait(for: [testExpectation], timeout: 1.0)
    }

    func testDeleteDatabase() {
        let testExpectation = expectation(description: "TestDeleteDatabase")
        let testEntity = TestSearchListEntity(searchKeyword: "TestKeyword")
        
        testRealmSwiftDBSearchList.insertDatabase(searchListEntity: testEntity)
            .flatMap { [unowned self] _ in
                self.testRealmSwiftDBSearchList.deleteDatabase(searchKeyword: "TestKeyword")
            }
            .flatMap { [unowned self] _ in
                self.testRealmSwiftDBSearchList.selectDatabase(searchKeyword: "TestKeyword") as AnyPublisher<[TestSearchListEntity], Error>
            }
            .sink(
                receiveCompletion: { testCompletion in
                    if case .failure(let testError) = testCompletion {
                        XCTFail("삭제 실패: \(testError)")
                    }
                },
                receiveValue: { testResult in
                    XCTAssertTrue(testResult.isEmpty)
                    
                    testExpectation.fulfill()
                }
            )
            .store(in: &testCancellables)

        wait(for: [testExpectation], timeout: 1.0)
    }

    func testDeleteAllDatabase() {
        let testExpectation = expectation(description: "TestDeleteAllDatabase")
        let testEntity1 = TestSearchListEntity(searchKeyword: "TestKeyword1")
        let testEntity2 = TestSearchListEntity(searchKeyword: "TestKeyword2")
        
        testRealmSwiftDBSearchList.insertDatabase(searchListEntity: testEntity1)
            .flatMap { [unowned self] _ in
                self.testRealmSwiftDBSearchList.insertDatabase(searchListEntity: testEntity2)
            }
            .flatMap { [unowned self] _ in
                self.testRealmSwiftDBSearchList.deleteAllDatabase()
            }
            .flatMap { [unowned self] _ in
                self.testRealmSwiftDBSearchList.selectAllDatabase() as AnyPublisher<[TestSearchListEntity], Error>
            }
            .sink(
                receiveCompletion: { testCompletion in
                    if case .failure(let testError) = testCompletion {
                        XCTFail("전체 삭제 실패: \(testError)")
                    }
                },
                receiveValue: { testResult in
                    XCTAssertTrue(testResult.isEmpty)
                    
                    testExpectation.fulfill()
                }
            )
            .store(in: &testCancellables)

        wait(for: [testExpectation], timeout: 1.0)
    }
}
*/
