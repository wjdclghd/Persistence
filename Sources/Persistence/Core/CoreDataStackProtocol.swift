//
//  CoreDataStackProtocol.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
import CoreData

/// Core Data stack가 외부에 제공해야 하는 최소 계약입니다.
///
/// NSPersistentContainer 전체를 노출하지 않고,
/// 저장소를 사용하는 상위 계층이 실제로 필요한 기능만 접근하도록 제한합니다.
/// Store 구현체가 계약에 의존하므로 테스트에서 in-memory stack으로 대체할 수 있습니다.
protocol CoreDataStackProtocol: AnyObject, Sendable {
    /// 메인 큐에서 동작하는 기본 context입니다.
    ///
    /// UI 바인딩, 변경 감지, background context 저장 결과 병합에 사용합니다.
    /// 일반적으로 장시간 유지되는 관찰용 context로 다루며,
    /// 무거운 쓰기 작업은 background context에서 수행하는 것을 권장합니다.
    var viewContext: NSManagedObjectContext { get }

    /// background 작업용 context를 새로 생성합니다.
    ///
    /// 작업마다 독립적인 context를 사용하면,
    /// 작업 범위와 생명주기를 분리할 수 있고 큐 충돌 가능성을 줄일 수 있습니다.
    ///
    /// - Returns: background queue에 연결된 NSManagedObjectContext
    func newBackgroundContext() -> NSManagedObjectContext

    /// background context에서 읽기 작업을 수행합니다.
    ///
    /// 이 메서드는 조회 전용 실행 경로입니다.
    /// save를 호출하지 않으며, 전달받은 작업 클로저를 background context 전용 큐에서 실행한 뒤
    /// 반환값을 그대로 상위 계층으로 전달합니다.
    ///
    /// - Parameters:
    ///   - block: background context 전용 큐에서 실행할 읽기 작업 클로저
    ///
    /// - Returns: block이 생성한 결과 값
    ///
    /// - Throws: block 실행 중 발생한 오류
    func performRead<T>(
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T

    /// background context에서 쓰기 작업을 수행하고 save까지 처리합니다.
    ///
    /// 삽입, 수정, 삭제가 필요한 작업은 이 메서드를 통해 실행합니다.
    /// 호출자는 작업 클로저 안에서 비즈니스 로직에 집중하고,
    /// 저장 시점과 저장 실패 처리는 stack 계층이 담당합니다.
    ///
    /// - Parameters:
    ///   - block: background context 전용 큐에서 실행할 쓰기 작업 클로저
    ///
    /// - Returns: block이 생성한 결과 값
    ///
    /// - Throws: block 실행 중 발생한 오류, save 과정에서 발생한 오류
    func performWrite<T>(
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T
}
