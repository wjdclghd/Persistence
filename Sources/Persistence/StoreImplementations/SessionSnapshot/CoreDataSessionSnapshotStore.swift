//
//  CoreDataSessionSnapshotStore.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 SessionSnapshotStoreProtocol의 Core Data 구현체입니다.

 이 타입은 세션 스냅샷 엔티티를 대상으로 조회, 저장, 삭제 기능을 제공합니다.
 상위 계층은 SessionSnapshot만 다루고,
 실제 Core Data fetch request 작성, upsert 처리, 삭제 작업은 이 구현체가 담당합니다.

 저장 정책
 - environment를 기준으로 기존 레코드가 있으면 값을 갱신합니다.
 - 동일 environment가 없으면 새 ManagedObject를 추가합니다.
 - 저장 전 environment와 userID 앞뒤 공백을 정리합니다.
 - 정리 결과 userID가 비어 있으면 nil로 저장합니다.

 조회 정책
 - 전체 조회는 environment 오름차순으로 정렬합니다.
 - 단건 조회는 environment 정확 일치 기준으로 수행합니다.
 */
final class CoreDataSessionSnapshotStore: SessionSnapshotStoreProtocol {
    private let coreDataStack: CoreDataStackProtocol

    /*
     SessionSnapshot Core Data 저장소를 생성합니다.

     Parameters:
     - coreDataStack: 세션 스냅샷 저장에 사용할 Core Data stack 계약
     */
    init(coreDataStack: CoreDataStackProtocol) {
        self.coreDataStack = coreDataStack
    }

    /*
     저장된 세션 스냅샷 전체 목록을 조회합니다.

     Returns:
     - 정렬된 세션 스냅샷 목록

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchAll() async throws -> [SessionSnapshot] {
        try await coreDataStack.performRead { context in
            try self.fetchSnapshots(
                predicate: nil,
                in: context
            )
        }
    }

    /*
     지정한 환경의 세션 스냅샷을 조회합니다.

     Parameters:
     - environment: 조회할 세션 환경 식별자

     Returns:
     - 일치하는 세션 스냅샷이 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchSnapshot(for environment: String) async throws -> SessionSnapshot? {
        let normalizedEnvironment = normalizeEnvironment(environment)

        guard normalizedEnvironment.isEmpty == false else {
            return nil
        }

        return try await coreDataStack.performRead { context in
            try self.fetchManagedObject(
                environment: normalizedEnvironment,
                in: context
            ).map(SessionSnapshotMapper.toSnapshot)
        }
    }

    /*
     세션 스냅샷을 저장합니다.

     environment가 이미 존재하면 기존 레코드를 갱신하고,
     존재하지 않으면 새 레코드를 삽입합니다.

     Parameters:
     - snapshot: 저장할 세션 스냅샷 값

     Throws:
     - environment가 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func save(_ snapshot: SessionSnapshot) async throws {
        let normalizedSnapshot = try makeNormalizedSnapshot(snapshot)

        _ = try await coreDataStack.performWrite { context in
            if let existingManagedObject = try self.fetchManagedObject(
                environment: normalizedSnapshot.environment,
                in: context
            ) {
                SessionSnapshotMapper.update(
                    existingManagedObject,
                    from: normalizedSnapshot
                )
            } else {
                _ = SessionSnapshotMapper.insert(
                    from: normalizedSnapshot,
                    into: context
                )
            }
        }
    }

    /*
     지정한 환경의 세션 스냅샷을 삭제합니다.

     전달한 environment를 앞뒤 공백 제거 후 비교하며,
     일치하는 레코드가 없으면 아무 작업도 하지 않습니다.

     Parameters:
     - environment: 삭제할 세션 환경 식별자

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func delete(environment: String) async throws {
        let normalizedEnvironment = normalizeEnvironment(environment)

        guard normalizedEnvironment.isEmpty == false else {
            return
        }

        _ = try await coreDataStack.performWrite { context in
            guard let managedObject = try self.fetchManagedObject(
                environment: normalizedEnvironment,
                in: context
            ) else {
                return
            }

            context.delete(managedObject)
        }
    }

    /*
     저장된 세션 스냅샷을 모두 삭제합니다.

     Throws:
     - 삭제 작업 또는 save 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func deleteAll() async throws {
        _ = try await coreDataStack.performWrite { context in
            let request = SessionSnapshotMO.fetchRequest()
            let managedObjects = try context.fetch(request)

            managedObjects.forEach(context.delete)
        }
    }
}

private extension CoreDataSessionSnapshotStore {
    /*
     지정한 predicate로 세션 스냅샷을 조회합니다.

     Parameters:
     - predicate: 조회 조건. nil이면 전체 조회를 수행합니다.
     - context: fetch를 수행할 context

     Returns:
     - 정렬된 세션 스냅샷 목록

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchSnapshots(
        predicate: NSPredicate?,
        in context: NSManagedObjectContext
    ) throws -> [SessionSnapshot] {
        let request = SessionSnapshotMO.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(SessionSnapshotMO.environment), ascending: true)
        ]

        return try context.fetch(request).map(SessionSnapshotMapper.toSnapshot)
    }

    /*
     environment가 일치하는 기존 세션 스냅샷 ManagedObject를 조회합니다.

     Parameters:
     - environment: 조회할 environment 값
     - context: fetch를 수행할 context

     Returns:
     - 일치하는 ManagedObject가 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchManagedObject(
        environment: String,
        in context: NSManagedObjectContext
    ) throws -> SessionSnapshotMO? {
        let request = SessionSnapshotMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "environment == %@", environment)
        return try context.fetch(request).first
    }

    /*
     저장용 세션 스냅샷을 정규화합니다.

     저장 전 environment와 userID 앞뒤 공백을 제거하고,
     environment가 비어 있으면 쓰기 실패로 처리합니다.
     userID는 정리 결과 비어 있으면 nil로 변환합니다.

     Parameters:
     - snapshot: 호출부가 전달한 세션 스냅샷 값

     Returns:
     - 정규화된 세션 스냅샷 값

     Throws:
     - environment가 비어 있으면 PersistenceError.writeFailed를 던집니다.
     */
    func makeNormalizedSnapshot(
        _ snapshot: SessionSnapshot
    ) throws -> SessionSnapshot {
        let normalizedEnvironment = normalizeEnvironment(snapshot.environment)

        guard normalizedEnvironment.isEmpty == false else {
            throw PersistenceError.writeFailed(
                "세션 스냅샷 environment는 비어 있을 수 없습니다."
            )
        }

        return SessionSnapshot(
            environment: normalizedEnvironment,
            isLoggedIn: snapshot.isLoggedIn,
            lastRefreshedAt: snapshot.lastRefreshedAt,
            userID: normalizeOptionalValue(snapshot.userID)
        )
    }

    /*
     비교에 사용할 environment 값을 정규화합니다.

     Parameters:
     - environment: 호출부가 전달한 원본 environment 값

     Returns:
     - 앞뒤 공백이 제거된 environment 값
     */
    func normalizeEnvironment(_ environment: String) -> String {
        normalizeValue(environment)
    }

    /*
     선택 문자열 값을 정규화합니다.

     Parameters:
     - value: 호출부가 전달한 문자열 값

     Returns:
     - 앞뒤 공백 제거 후 비어 있으면 nil, 아니면 정리된 문자열 값
     */
    func normalizeOptionalValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalizedValue = normalizeValue(value)
        return normalizedValue.isEmpty ? nil : normalizedValue
    }

    /*
     문자열 값을 정규화합니다.

     Parameters:
     - value: 호출부가 전달한 원본 문자열 값

     Returns:
     - 앞뒤 공백이 제거된 문자열 값
     */
    func normalizeValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
