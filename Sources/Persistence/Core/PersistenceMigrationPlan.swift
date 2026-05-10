//
//  PersistenceMigrationPlan.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/// Persistence 저장소를 열 때 사용할 migration 정책을 정의하는 설정 타입입니다.
///
/// Core Data는 persistent store를 로드하는 시점에
/// automatic migration 수행 여부와 mapping model 자동 추론 여부를 함께 전달받습니다.
/// 이 타입은 해당 옵션을 한 곳에서 관리하기 위한 값 객체입니다.
///
/// PersistenceConfiguration은 이 값을 사용해 store description을 구성하고,
/// CoreDataStack은 준비된 description으로 persistent store를 로드합니다.
/// 호출부는 이 타입을 통해 migration 허용 여부를 목적에 맞게 선택할 수 있습니다.
public struct PersistenceMigrationPlan: Equatable, Sendable {
    /// store 로딩 시 Core Data가 automatic migration을 시도할지 여부입니다.
    ///
    /// true이면 기존 store 메타데이터와 현재 모델을 비교하여
    /// Core Data가 자동 migration 가능 여부를 판단합니다.
    /// false이면 모델이 호환되지 않는 경우 store 로딩이 실패합니다.
    public let shouldMigrateStoreAutomatically: Bool

    /// Core Data가 mapping model을 자동으로 추론할지 여부입니다.
    ///
    /// true이면 lightweight migration에 해당하는 변경을
    /// 별도 mapping model 없이 Core Data가 자동으로 유추할 수 있습니다.
    /// 이 옵션은 automatic migration이 활성화된 경우에만 의미가 있습니다.
    public let shouldInferMappingModelAutomatically: Bool

    /// migration 정책을 생성합니다.
    ///
    /// - Parameters:
    ///   - shouldMigrateStoreAutomatically: store 로딩 시 automatic migration 시도 여부
    ///   - shouldInferMappingModelAutomatically: lightweight migration용 mapping model 자동 추론 여부
    public init(
        shouldMigrateStoreAutomatically: Bool = true,
        shouldInferMappingModelAutomatically: Bool = true
    ) {
        self.shouldMigrateStoreAutomatically = shouldMigrateStoreAutomatically
        self.shouldInferMappingModelAutomatically = shouldInferMappingModelAutomatically
    }

    /// 일반적인 lightweight migration 정책입니다.
    ///
    /// 속성 추가, optional 변경처럼 Core Data가 자동 추론 가능한 변경에 적합합니다.
    /// Persistence 모듈의 기본 migration 정책으로 사용할 수 있습니다.
    public static let lightweight = PersistenceMigrationPlan(
        shouldMigrateStoreAutomatically: true,
        shouldInferMappingModelAutomatically: true
    )

    /// migration을 수행하지 않는 정책입니다.
    ///
    /// 현재 모델과 store 메타데이터가 호환되지 않으면
    /// store 로딩을 즉시 실패시켜야 하는 환경에서 사용할 수 있습니다.
    public static let disabled = PersistenceMigrationPlan(
        shouldMigrateStoreAutomatically: false,
        shouldInferMappingModelAutomatically: false
    )
}

extension PersistenceMigrationPlan {
    /// migration 정책 조합이 유효한지 검증합니다.
    ///
    /// inferred mapping model은 automatic migration이 활성화된 경우에만 의미가 있으므로,
    /// automatic migration은 꺼져 있는데 inferred mapping만 켜진 조합은 허용하지 않습니다.
    ///
    /// - Throws: PersistenceError.invalidConfiguration: 논리적으로 허용되지 않는 정책 조합인 경우
    func validate() throws {
        if shouldMigrateStoreAutomatically == false,
           shouldInferMappingModelAutomatically == true {
            throw PersistenceError.invalidConfiguration(
                "automatic migration이 비활성화된 상태에서는 inferred mapping model을 사용할 수 없습니다."
            )
        }
    }

    /// migration 정책을 NSPersistentStoreDescription에 적용합니다.
    ///
    /// store description은 persistent store 로딩 전에 준비되어야 하므로,
    /// 이 메서드는 loadPersistentStores 호출 이전 단계에서 사용합니다.
    ///
    /// - Parameters:
    ///   - description: migration option을 적용할 NSPersistentStoreDescription
    func apply(to description: NSPersistentStoreDescription) {
        description.shouldMigrateStoreAutomatically = shouldMigrateStoreAutomatically
        description.shouldInferMappingModelAutomatically = shouldInferMappingModelAutomatically
    }
}
