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

/*
 PersistenceMigrationPlan의 기본 정책값과 검증 동작을 확인하는 테스트입니다.

 이 테스트는 migration 정책이 NSPersistentStoreDescription에 올바르게 반영되는지,
 invalid한 정책 조합을 사전에 차단하는지,
 lightweight와 disabled 정책이 의도한 값을 가지는지를 검증합니다.
 */
final class PersistenceMigrationPlanTests: XCTestCase {
    /*
     lightweight 정책이 automatic migration과 inferred mapping model을 모두 활성화하는지 검증합니다.

     일반적인 SQLite store 운영 환경에서는 이 정책이 기본값으로 사용되므로,
     두 옵션이 모두 true인지 확인합니다.
     */
    func test_lightweight_hasExpectedDefaultValues() {
        let plan = PersistenceMigrationPlan.lightweight

        XCTAssertTrue(plan.shouldMigrateStoreAutomatically)
        XCTAssertTrue(plan.shouldInferMappingModelAutomatically)
    }

    /*
     disabled 정책이 automatic migration과 inferred mapping model을 모두 비활성화하는지 검증합니다.

     호환되지 않는 store를 즉시 실패로 처리하려는 경우를 위해,
     두 옵션이 모두 false인지 확인합니다.
     */
    func test_disabled_hasExpectedDefaultValues() {
        let plan = PersistenceMigrationPlan.disabled

        XCTAssertFalse(plan.shouldMigrateStoreAutomatically)
        XCTAssertFalse(plan.shouldInferMappingModelAutomatically)
    }

    /*
     migration 정책을 store description에 적용하면 관련 Core Data 옵션이 동일하게 기록되는지 검증합니다.

     Core Data는 store 로딩 시점에 description의 option을 읽으므로,
     plan 값이 description에 정확히 복사되는지가 중요합니다.
     */
    func test_apply_writesMigrationOptionsIntoPersistentStoreDescription() {
        let description = NSPersistentStoreDescription()
        let plan = PersistenceMigrationPlan(
            shouldMigrateStoreAutomatically: true,
            shouldInferMappingModelAutomatically: false
        )

        plan.apply(to: description)

        XCTAssertTrue(description.shouldMigrateStoreAutomatically)
        XCTAssertFalse(description.shouldInferMappingModelAutomatically)
    }

    /*
     inferred mapping model만 활성화한 정책 조합이 invalidConfiguration으로 차단되는지 검증합니다.

     inferred mapping model은 automatic migration이 켜져 있어야만 의미가 있으므로,
     migrate는 false이고 infer만 true인 조합은 허용되지 않아야 합니다.
     */
    func test_validate_whenInferIsEnabledWithoutAutomaticMigration_throwsInvalidConfiguration() {
        let plan = PersistenceMigrationPlan(
            shouldMigrateStoreAutomatically: false,
            shouldInferMappingModelAutomatically: true
        )

        XCTAssertThrowsError(try plan.validate()) { error in
            guard case let PersistenceError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     automatic migration이 활성화된 정상 정책 조합은 검증을 통과하는지 확인합니다.

     기본 lightweight migration 경로가 설정 오류로 오인되지 않아야 하므로,
     예외 없이 validate를 통과하는지 확인합니다.
     */
    func test_validate_withLightweightPlan_doesNotThrow() throws {
        try PersistenceMigrationPlan.lightweight.validate()
    }
}
