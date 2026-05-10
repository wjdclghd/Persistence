//
//  PersistenceMigrationPlanTests.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData
import XCTest
@testable import Persistence

/// PersistenceMigrationPlan의 기본 정책값과 검증 동작을 확인하는 테스트입니다.
final class PersistenceMigrationPlanTests: XCTestCase {
    func test_lightweight_whenUsingDefaultFactory_hasExpectedDefaultValues() {
        // given / when
        let plan = PersistenceMigrationPlan.lightweight

        // then
        XCTAssertTrue(plan.shouldMigrateStoreAutomatically)
        XCTAssertTrue(plan.shouldInferMappingModelAutomatically)
    }

    func test_disabled_whenUsingDefaultFactory_hasExpectedDefaultValues() {
        // given / when
        let plan = PersistenceMigrationPlan.disabled

        // then
        XCTAssertFalse(plan.shouldMigrateStoreAutomatically)
        XCTAssertFalse(plan.shouldInferMappingModelAutomatically)
    }

    func test_apply_withDescription_writesMigrationOptions() {
        // given
        let description = NSPersistentStoreDescription()
        let plan = PersistenceMigrationPlan(
            shouldMigrateStoreAutomatically: true,
            shouldInferMappingModelAutomatically: false
        )

        // when
        plan.apply(to: description)

        // then
        XCTAssertTrue(description.shouldMigrateStoreAutomatically)
        XCTAssertFalse(description.shouldInferMappingModelAutomatically)
    }

    func test_validate_whenInferIsEnabledWithoutAutomaticMigration_throwsInvalidConfiguration() {
        // given
        let plan = PersistenceMigrationPlan(
            shouldMigrateStoreAutomatically: false,
            shouldInferMappingModelAutomatically: true
        )

        // when / then
        XCTAssertThrowsError(try plan.validate()) { error in
            guard case let PersistenceError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_validate_withLightweightPlan_doesNotThrow() throws {
        // given
        let plan = PersistenceMigrationPlan.lightweight

        // when / then
        XCTAssertNoThrow(try plan.validate())
    }
}
