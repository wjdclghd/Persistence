//
//  InMemoryManagedObjectContext.swift
//  Persistence
//
//  Created by jch on 4/4/26.
//

import Foundation
import CoreData
@testable import Persistence

/*
 테스트 전용 in-memory NSManagedObjectContext 생성 도우미입니다.

 Mapper 테스트는 Core Data Stack 전체를 구성하지 않아도,
 programmatic model 기반의 in-memory context만 있으면 ManagedObject 생성과 변환을 충분히 검증할 수 있습니다.
 이 타입은 Mapper 테스트가 Core Data 저장 구조를 간단하고 독립적으로 사용할 수 있도록 도와줍니다.
 */
enum InMemoryManagedObjectContext {
    /*
     기본 programmatic model을 사용하는 in-memory context를 생성합니다.

     Returns:
     - Mapper 테스트에서 바로 사용할 수 있는 NSManagedObjectContext

     Throws:
     - in-memory persistent store 추가에 실패하면 에러를 던집니다.
     */
    static func make() throws -> NSManagedObjectContext {
        let model = ProgrammaticPersistenceModel.makeDefaultModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(
            ofType: NSInMemoryStoreType,
            configurationName: nil,
            at: nil,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
