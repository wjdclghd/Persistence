//
//  InMemoryCoreDataStack.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
@testable import Persistence

/*
 테스트 전용 in-memory CoreDataStack 생성 도우미입니다.

 테스트에서는 디스크 기반 SQLite store 대신 in-memory store를 사용하여
 테스트 실행 속도를 높이고, 파일 생성이나 정리 작업 없이
 독립적인 실행 환경을 만들 수 있어야 합니다.

 이 타입은 bundle 기반 모델과 programmatic 모델을 모두 사용할 수 있도록,
 PersistenceConfiguration.inMemory를 감싼 테스트 진입점 역할을 합니다.
 */
enum InMemoryCoreDataStack {
    /*
     bundle 리소스를 사용하는 in-memory CoreDataStack을 생성합니다.

     Parameters:
     - modelName: 로드할 Core Data 모델 이름
     - modelBundle: Core Data 모델 리소스가 포함된 번들

     Returns:
     - 테스트에서 바로 사용할 수 있는 CoreDataStackProtocol 구현 객체

     Throws:
     - Core Data 모델 로딩 또는 persistent store 초기화에 실패하면 에러를 던집니다.
     */
    static func make(
        modelName: String = "PersistenceModel",
        modelBundle: Bundle = .module
    ) async throws -> CoreDataStackProtocol {
        let configuration = PersistenceConfiguration.inMemory(
            modelName: modelName,
            modelBundle: modelBundle
        )
        return try await CoreDataStack.make(configuration: configuration)
    }

    /*
     지정한 modelSource를 사용하는 in-memory CoreDataStack을 생성합니다.

     .xcdatamodeld 기반 모델과 programmatic 모델을 같은 테스트 진입점에서
     교체하여 검증할 수 있도록 구성합니다.

     Parameters:
     - modelSource: 사용할 Core Data 모델 공급 방식

     Returns:
     - 테스트에서 바로 사용할 수 있는 CoreDataStackProtocol 구현 객체

     Throws:
     - 모델 생성 또는 persistent store 초기화에 실패하면 에러를 던집니다.
     */
    static func make(
        modelSource: PersistenceConfiguration.ManagedObjectModelSource
    ) async throws -> CoreDataStackProtocol {
        let configuration = PersistenceConfiguration.inMemory(
            modelSource: modelSource
        )
        return try await CoreDataStack.make(configuration: configuration)
    }
}
