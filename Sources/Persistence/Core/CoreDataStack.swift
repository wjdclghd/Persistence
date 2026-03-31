//
//  CoreDataStack.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
import CoreData

/*
 Persistence 모듈의 Core Data 기반 stack 구현체입니다.

 이 타입은 Core Data 저장소를 사용할 수 있도록 foundation을 구성하고,
 상위 계층이 안전한 방식으로 context를 사용할 수 있게 공통 실행 경로를 제공합니다.

 담당 역할
 - Core Data 모델 로딩
 - NSPersistentContainer 생성
 - persistent store description 주입
 - persistent store 로딩
 - viewContext 정책 구성
 - background context 생성
 - 읽기/쓰기 실행 경로 제공

 지원하는 모델 로딩 방식
 - 번들 리소스의 .xcdatamodeld, .momd, .mom 로딩
 - 코드로 생성한 NSManagedObjectModel 직접 주입

 migration 정책 처리 방식
 - migration option 결정은 PersistenceConfiguration이 담당합니다.
 - 이 타입은 configuration이 준비한 store description을 container에 주입하고 로드합니다.
 - 따라서 migration 정책 변경은 stack 내부 분기보다 configuration 값 변경을 통해 수행합니다.

 담당하지 않는 역할
 - 엔터티별 조회 조건 구성
 - 도메인 레코드 매핑
 - 검색 기록, 캐시, 즐겨찾기 등의 CRUD 상세 구현

 위와 같은 세부 저장 로직은 Store 계층에서 담당하고,
 이 타입은 저장소 기반 기능을 안정적으로 실행하는 공통 기반에 집중합니다.
 */
final class CoreDataStack: CoreDataStackProtocol {
    private let persistentContainer: NSPersistentContainer
    private let configuration: PersistenceConfiguration

    /*
     메인 큐에서 동작하는 기본 context입니다.

     화면 관찰, 변경 병합, 가벼운 읽기 작업에 사용합니다.
     장시간 유지되는 context이므로,
     다량 쓰기 작업은 별도의 background context에서 처리하는 구성을 기본값으로 둡니다.
     */
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

    /*
     Core Data 모델과 persistent store 로딩이 완료된 stack을 생성합니다.

     생성 순서
     1. 설정값 검증
     2. modelSource에 따라 NSManagedObjectModel 준비
     3. NSPersistentContainer 생성
     4. store description 주입
     5. persistent store 로딩
     6. viewContext 정책 적용

     Parameters:
     - configuration: 모델 공급 방식, 저장소 종류, merge policy, migration 정책 등을 담은 설정값

     Returns:
     - 초기화가 완료된 CoreDataStack 인스턴스

     Throws:
     - 설정값이 올바르지 않은 경우
     - 모델을 찾지 못한 경우
     - programmatic 모델 구성이 잘못된 경우
     - persistent store 로딩에 실패한 경우
     */
    static func make(configuration: PersistenceConfiguration) async throws -> CoreDataStack {
        try configuration.validate()

        let managedObjectModel = try makeManagedObjectModel(
            from: configuration.modelSource
        )

        let persistentContainer = NSPersistentContainer(
            name: configuration.modelName,
            managedObjectModel: managedObjectModel
        )

        /*
         NSPersistentStoreDescription은 store 로딩 전에 설정해야 합니다.
         로딩 이후에 값을 바꿔도 이미 연결된 store에는 반영되지 않습니다.
         migration option도 동일하게 이 시점에 함께 적용되어야 합니다.
         */
        persistentContainer.persistentStoreDescriptions = [
            configuration.persistentStoreDescription
        ]

        try await loadPersistentStores(for: persistentContainer)

        return CoreDataStack(
            persistentContainer: persistentContainer,
            configuration: configuration
        )
    }

    /*
     background queue에서 사용할 새 context를 생성합니다.

     작업 단위마다 별도의 context를 생성하면,
     각 작업의 변경 범위를 분리할 수 있고 동시에 여러 작업이 실행되더라도
     개별 작업의 저장 흐름을 독립적으로 관리할 수 있습니다.

     Returns:
     - background queue에 연결된 NSManagedObjectContext
     */
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = configuration.backgroundContextMergePolicy.nsMergePolicy
        context.undoManager = nil
        context.name = "Persistence.backgroundContext"
        return context
    }

    /*
     background context에서 읽기 작업을 수행합니다.

     조회 전용 경로이므로 save는 수행하지 않습니다.
     전달받은 작업 클로저는 background context 전용 큐에서 실행되며,
     반환값은 그대로 상위 계층에 전달됩니다.

     호출 예시
     - 검색 기록 목록 조회
     - 특정 캐시 항목 조회
     - 즐겨찾기 존재 여부 확인

     Parameters:
     - block: background context 전용 큐에서 실행할 조회 작업 클로저

     Returns:
     - block이 생성한 결과 값

     Throws:
     - block 실행 실패 시 PersistenceError.readFailed
     */
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

    /*
     background context에서 쓰기 작업을 수행하고 save까지 처리합니다.

     삽입, 수정, 삭제를 포함하는 작업은 이 경로를 통해 실행합니다.
     전달받은 작업 클로저는 background context 전용 큐에서 실행되며,
     호출자는 클로저 안에서 필요한 객체 변경만 수행하고,
     실제 save 호출은 stack이 공통 규칙에 따라 처리합니다.

     호출 예시
     - 검색 기록 추가 또는 삭제
     - 캐시 항목 갱신
     - 세션 스냅샷 저장

     Parameters:
     - block: background context 전용 큐에서 실행할 쓰기 작업 클로저

     Returns:
     - block이 생성한 결과 값

     Throws:
     - block 실행 실패 또는 save 실패 시 PersistenceError.writeFailed
     */
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
    /*
     viewContext의 기본 동작 정책을 설정합니다.

     설정 항목
     - merge policy 적용
     - background context 저장 결과 자동 병합 여부 적용
     - undoManager 제거
     - 디버깅용 context 이름 지정

     background context가 저장한 변경 사항을 viewContext가 자동으로 병합하면,
     화면 계층이 최신 상태를 반영하기 쉬워집니다.
     */
    func configureViewContext() {
        viewContext.mergePolicy = configuration.viewContextMergePolicy.nsMergePolicy
        viewContext.automaticallyMergesChangesFromParent =
            configuration.viewContextAutomaticallyMergesChangesFromParent
        viewContext.undoManager = nil
        viewContext.name = "Persistence.viewContext"
    }

    /*
     callback 기반의 loadPersistentStores API를 async/await 형태로 감쌉니다.

     NSPersistentContainer는 store 로딩 결과를 completion handler로 전달합니다.
     모듈 외부에서는 async/await 형태로 사용하는 편이 호출 흐름을 단순하게 유지할 수 있으므로,
     continuation을 사용해 비동기 인터페이스로 변환합니다.

     Parameters:
     - container: store를 로드할 NSPersistentContainer

     Throws:
     - store 연결 실패 시 PersistenceError.persistentStoreLoadFailed
     */
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

    /*
     설정에 포함된 모델 공급 방식에 따라 NSManagedObjectModel을 준비합니다.

     bundle 모델은 번들 리소스에서 .momd 또는 .mom을 찾아 로드하고,
     programmatic 모델은 전달받은 빌더 클로저를 실행해 직접 생성합니다.
     생성된 모델은 최소 유효성 검사를 거친 뒤 반환합니다.

     Parameters:
     - source: 모델 공급 방식

     Returns:
     - 검증을 통과한 NSManagedObjectModel

     Throws:
     - PersistenceError.modelNotFound
     - PersistenceError.invalidConfiguration
     - programmatic 모델 생성 중 발생한 오류
     */
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

    /*
     생성된 NSManagedObjectModel이 최소한의 유효성을 만족하는지 확인합니다.

     빈 엔티티 목록이나 이름이 없는 엔티티는 실제 store 생성과 fetch 단계에서
     더 모호한 오류를 만들 수 있으므로, stack 초기화 시점에 선제적으로 차단합니다.

     Parameters:
     - model: 검증할 NSManagedObjectModel

     Throws:
     - PersistenceError.invalidConfiguration
     */
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
