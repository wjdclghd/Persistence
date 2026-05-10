//
//  InMemoryCoreDataStack.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
@testable import Persistence

/// 테스트 전용 in-memory CoreDataStack 생성 도우미입니다.
enum InMemoryCoreDataStack {
    /// bundle 리소스를 사용하는 in-memory CoreDataStack을 생성합니다.
    ///
    /// - Parameters:
    ///   - modelName: 로드할 Core Data 모델 이름
    ///   - modelBundle: Core Data 모델 리소스가 포함된 번들
    /// - Returns: 테스트에서 바로 사용할 수 있는 `CoreDataStackProtocol` 구현 객체입니다.
    /// - Throws: Core Data 모델 로딩 또는 persistent store 초기화에 실패하면 `PersistenceError`를 던집니다.
    static func make(
        modelName: String = "PersistenceModel",
        modelBundle: Bundle = .module
    ) async throws -> any CoreDataStackProtocol {
        let configuration = PersistenceConfiguration.inMemory(
            modelName: modelName,
            modelBundle: modelBundle
        )
        return try await CoreDataStack.make(configuration: configuration)
    }

    /// 지정한 modelSource를 사용하는 in-memory CoreDataStack을 생성합니다.
    ///
    /// - Parameter modelSource: 사용할 Core Data 모델 공급 방식
    /// - Returns: 테스트에서 바로 사용할 수 있는 `CoreDataStackProtocol` 구현 객체입니다.
    /// - Throws: 모델 생성 또는 persistent store 초기화에 실패하면 `PersistenceError`를 던집니다.
    static func make(
        modelSource: PersistenceConfiguration.ManagedObjectModelSource
    ) async throws -> any CoreDataStackProtocol {
        let configuration = PersistenceConfiguration.inMemory(
            modelSource: modelSource
        )
        return try await CoreDataStack.make(configuration: configuration)
    }
}
