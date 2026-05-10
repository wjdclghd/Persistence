//
//  ContextExecutor.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
import CoreData

/// NSManagedObjectContext 전용 실행 유틸리티입니다.
///
/// Core Data context는 생성될 때 지정된 실행 큐에서만 안전하게 접근할 수 있습니다.
/// 이 타입은 context.perform 호출 방식을 공통화하여,
/// 읽기/쓰기 작업이 항상 올바른 큐에서 실행되도록 보장합니다.
///
/// 사용 목적
/// - context 전용 큐 강제
/// - 읽기 작업과 저장 작업의 실행 경로 분리
/// - save 시점을 한 곳에서 통제
///
/// 사용 방식
/// - 단순 조회 또는 save가 필요 없는 작업: perform(on:_:) 사용
/// - 삽입, 수정, 삭제처럼 save가 필요한 작업: performAndSave(on:_:) 사용
enum ContextExecutor {
    /// 지정한 context의 전용 큐에서 작업 클로저를 실행합니다.
    ///
    /// 읽기 작업이나 임시 계산처럼 save가 필요 없는 작업에 적합합니다.
    /// 전달받은 작업 클로저는 해당 context가 소유한 큐에서 실행되며,
    /// 반환한 값을 그대로 호출자에게 돌려줍니다.
    ///
    /// - Parameters:
    ///   - context: 작업을 실행할 NSManagedObjectContext
    ///   - block: context 전용 큐에서 실행할 작업 클로저
    ///
    /// - Returns: block이 생성한 결과 값
    ///
    /// - Throws: block 실행 중 발생한 오류
    static func perform<T>(
        on context: NSManagedObjectContext,
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await context.perform(schedule: .immediate) {
            try block(context)
        }
    }

    /// 지정한 context의 전용 큐에서 작업 클로저를 실행한 뒤,
    /// 변경 사항이 존재하면 save까지 수행합니다.
    ///
    /// 이 메서드는 쓰기 작업의 공통 진입점으로 사용합니다.
    /// 전달받은 작업 클로저 안에서는 삽입, 수정, 삭제만 수행하고,
    /// 실제 저장 여부 판단과 save 호출은 이 메서드가 담당합니다.
    ///
    /// context.hasChanges가 false이면 불필요한 save를 수행하지 않습니다.
    ///
    /// - Parameters:
    ///   - context: 작업과 저장을 수행할 NSManagedObjectContext
    ///   - block: context 전용 큐에서 실행할 쓰기 작업 클로저
    ///
    /// - Returns: block이 생성한 결과 값
    ///
    /// - Throws: block 실행 중 발생한 오류, save 과정에서 발생한 오류
    static func performAndSave<T>(
        on context: NSManagedObjectContext,
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        try await context.perform(schedule: .immediate) {
            let result = try block(context)

            if context.hasChanges {
                try context.save()
            }

            return result
        }
    }
}
