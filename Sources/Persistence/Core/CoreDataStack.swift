//
//  CoreDataStack.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
import CoreData

/// Persistence 모듈의 Core Data 기반 stack 구현체입니다.
///
/// Core Data 모델 로딩, NSPersistentContainer 생성, persistent store 로딩,
/// viewContext 정책 구성, 읽기/쓰기 실행 경로를 제공합니다.
/// bundle 리소스의 .xcdatamodeld와 코드로 생성한 NSManagedObjectModel을 모두 지원합니다.
final class CoreDataStack: CoreDataStackProtocol, @unchecked Sendable {
    private let persistentContainer: NSPersistentContainer
    private let configuration: PersistenceConfiguration

    /// 메인 큐에서 동작하는 기본 context입니다.
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    private init(
        persistentContainer: NSPersistentContainer,
        configuration: PersistenceConfiguration
    ) {
        self.persistentContainer = persistentContainer
        self.configuration = configuration
        configureViewContext()
    }

    /// Core Data 모델과 persistent store 로딩이 완료된 stack을 생성합니다.
    ///
    /// - Parameter configuration: 모델 공급 방식, 저장소 종류, merge policy, migration 정책 등을 담은 설정값입니다.
    /// - Returns: 초기화가 완료된 `CoreDataStack` 인스턴스입니다.
    /// - Throws: 설정값 검증 실패, 모델 로딩 실패, persistent store 로딩 실패 시 `PersistenceError`를 던집니다.
    static func make(configuration: PersistenceConfiguration) async throws -> CoreDataStack {
        try configuration.validate()

        let managedObjectModel = try makeManagedObjectModel(
            from: configuration.modelSource
        )

        let persistentContainer = NSPersistentContainer(
            name: configuration.modelName,
            managedObjectModel: managedObjectModel
        )

        // NSPersistentStoreDescription은 store 로딩 전에 설정해야 합니다.
        // 로딩 이후에 값을 바꿔도 이미 연결된 store에는 반영되지 않습니다.
        // migration option도 동일하게 이 시점에 함께 적용되어야 합니다.
        persistentContainer.persistentStoreDescriptions = [
            configuration.persistentStoreDescription
        ]

        try await loadPersistentStores(for: persistentContainer)

        return CoreDataStack(
            persistentContainer: persistentContainer,
            configuration: configuration
        )
    }

    /// background queue에서 사용할 새 context를 생성합니다.
    ///
    /// - Returns: background queue에 연결된 `NSManagedObjectContext`입니다.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = configuration.backgroundContextMergePolicy.nsMergePolicy
        context.undoManager = nil
        context.name = "Persistence.backgroundContext"
        return context
    }

    /// background context에서 읽기 작업을 수행합니다.
    ///
    /// - Parameter block: background context 전용 큐에서 실행할 조회 작업 클로저입니다.
    /// - Returns: `block`이 생성한 결과 값입니다.
    /// - Throws: block 실행 실패 시 `PersistenceError.readFailed`를 던집니다.
    func performRead<T>(
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = newBackgroundContext()

        do {
            return try await ContextExecutor.perform(on: context) { managedObjectContext in
                try block(managedObjectContext)
            }
        } catch {
            throw PersistenceError.readFailed(error.localizedDescription)
        }
    }

    /// background context에서 쓰기 작업을 수행하고 save까지 처리합니다.
    ///
    /// - Parameter block: background context 전용 큐에서 실행할 쓰기 작업 클로저입니다.
    /// - Returns: `block`이 생성한 결과 값입니다.
    /// - Throws: block 실행 실패 또는 save 실패 시 `PersistenceError.writeFailed`를 던집니다.
    func performWrite<T>(
        _ block: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = newBackgroundContext()

        do {
            return try await ContextExecutor.performAndSave(on: context) { managedObjectContext in
                try block(managedObjectContext)
            }
        } catch {
            throw PersistenceError.writeFailed(error.localizedDescription)
        }
    }
}

private extension CoreDataStack {
    func configureViewContext() {
        viewContext.mergePolicy = configuration.viewContextMergePolicy.nsMergePolicy
        viewContext.automaticallyMergesChangesFromParent =
            configuration.viewContextAutomaticallyMergesChangesFromParent
        viewContext.undoManager = nil
        viewContext.name = "Persistence.viewContext"
    }

    static func loadPersistentStores(
        for container: NSPersistentContainer
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(
                        throwing: PersistenceError.persistentStoreLoadFailed(
                            error.localizedDescription
                        )
                    )
                    return
                }

                continuation.resume()
            }
        }
    }

    static func makeManagedObjectModel(
        from source: PersistenceConfiguration.ManagedObjectModelSource
    ) throws -> NSManagedObjectModel {
        let managedObjectModel: NSManagedObjectModel

        switch source {
        case let .bundle(modelName, bundle):
            let bundlePath = bundle.bundlePath

            if let modelURL = bundle.url(forResource: modelName, withExtension: "momd") ??
                bundle.url(forResource: modelName, withExtension: "mom") {
                guard let bundleModel = NSManagedObjectModel(contentsOf: modelURL) else {
                    throw PersistenceError.modelNotFound(
                        modelName: modelName,
                        bundlePath: bundlePath
                    )
                }

                managedObjectModel = bundleModel
            } else {
                throw PersistenceError.modelNotFound(
                    modelName: modelName,
                    bundlePath: bundlePath
                )
            }

        case let .programmatic(_, makeManagedObjectModel):
            managedObjectModel = try makeManagedObjectModel()
        }

        try validateManagedObjectModel(managedObjectModel)
        return managedObjectModel
    }

    static func validateManagedObjectModel(
        _ model: NSManagedObjectModel
    ) throws {
        guard model.entities.isEmpty == false else {
            throw PersistenceError.invalidConfiguration("Core Data 모델에 엔터티가 하나 이상 필요합니다.")
        }

        let invalidEntity = model.entities.first {
            ($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if invalidEntity != nil {
            throw PersistenceError.invalidConfiguration("엔터티 이름은 비어 있을 수 없습니다.")
        }
    }
}
