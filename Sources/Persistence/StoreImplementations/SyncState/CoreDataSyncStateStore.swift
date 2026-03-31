//
//  CoreDataSyncStateStore.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 SyncStateStoreProtocol의 Core Data 구현체입니다.

 이 타입은 동기화 상태 엔티티를 대상으로 조회, 저장, 삭제 기능을 제공합니다.
 상위 계층은 SyncStateRecord만 다루고,
 실제 Core Data fetch request 작성, upsert 처리, 삭제 작업은 이 구현체가 담당합니다.

 저장 정책
 - namespace를 기준으로 기존 레코드가 있으면 값을 갱신합니다.
 - 동일 namespace가 없으면 새 ManagedObject를 추가합니다.
 - 저장 전 namespace와 cursor 앞뒤 공백을 정리합니다.
 - 정리 결과 cursor가 비어 있으면 nil로 저장합니다.

 조회 정책
 - 전체 조회는 namespace 오름차순으로 정렬합니다.
 - 단건 조회는 namespace 정확 일치 기준으로 수행합니다.
 */
final class CoreDataSyncStateStore: SyncStateStoreProtocol {
    private let coreDataStack: CoreDataStackProtocol

    /*
     SyncState Core Data 저장소를 생성합니다.

     Parameters:
     - coreDataStack: 동기화 상태 저장에 사용할 Core Data stack 계약
     */
    init(coreDataStack: CoreDataStackProtocol) {
        self.coreDataStack = coreDataStack
    }

    /*
     저장된 동기화 상태 전체 목록을 조회합니다.

     Returns:
     - 정렬된 동기화 상태 목록

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchAll() async throws -> [SyncStateRecord] {
        try await coreDataStack.performRead { context in
            try self.fetchRecords(
                predicate: nil,
                in: context
            )
        }
    }

    /*
     지정한 namespace의 동기화 상태를 조회합니다.

     Parameters:
     - namespace: 조회할 동기화 namespace

     Returns:
     - 일치하는 동기화 상태가 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecord(for namespace: String) async throws -> SyncStateRecord? {
        let normalizedNamespace = normalizeValue(namespace)

        guard normalizedNamespace.isEmpty == false else {
            return nil
        }

        return try await coreDataStack.performRead { context in
            try self.fetchManagedObject(
                namespace: normalizedNamespace,
                in: context
            ).map(SyncStateRecordMapper.toRecord)
        }
    }

    /*
     동기화 상태를 저장합니다.

     namespace가 이미 존재하면 기존 레코드를 갱신하고,
     존재하지 않으면 새 레코드를 삽입합니다.

     Parameters:
     - record: 저장할 동기화 상태 값

     Throws:
     - namespace가 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func save(_ record: SyncStateRecord) async throws {
        let normalizedRecord = try makeNormalizedRecord(record)

        _ = try await coreDataStack.performWrite { context in
            if let existingManagedObject = try self.fetchManagedObject(
                namespace: normalizedRecord.namespace,
                in: context
            ) {
                SyncStateRecordMapper.update(
                    existingManagedObject,
                    from: normalizedRecord
                )
            } else {
                _ = SyncStateRecordMapper.insert(
                    from: normalizedRecord,
                    into: context
                )
            }
        }
    }

    /*
     지정한 namespace의 동기화 상태를 삭제합니다.

     전달한 namespace를 앞뒤 공백 제거 후 비교하며,
     일치하는 레코드가 없으면 아무 작업도 하지 않습니다.

     Parameters:
     - namespace: 삭제할 동기화 namespace

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func delete(namespace: String) async throws {
        let normalizedNamespace = normalizeValue(namespace)

        guard normalizedNamespace.isEmpty == false else {
            return
        }

        _ = try await coreDataStack.performWrite { context in
            guard let managedObject = try self.fetchManagedObject(
                namespace: normalizedNamespace,
                in: context
            ) else {
                return
            }

            context.delete(managedObject)
        }
    }

    /*
     저장된 동기화 상태를 모두 삭제합니다.

     Throws:
     - 삭제 작업 또는 save 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func deleteAll() async throws {
        _ = try await coreDataStack.performWrite { context in
            let request = SyncStateRecordMO.fetchRequest()
            let managedObjects = try context.fetch(request)

            managedObjects.forEach(context.delete)
        }
    }
}

private extension CoreDataSyncStateStore {
    /*
     지정한 predicate로 동기화 상태를 조회합니다.

     Parameters:
     - predicate: 조회 조건. nil이면 전체 조회를 수행합니다.
     - context: fetch를 수행할 context

     Returns:
     - 정렬된 동기화 상태 목록

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecords(
        predicate: NSPredicate?,
        in context: NSManagedObjectContext
    ) throws -> [SyncStateRecord] {
        let request = SyncStateRecordMO.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(SyncStateRecordMO.namespace), ascending: true)
        ]

        return try context.fetch(request).map(SyncStateRecordMapper.toRecord)
    }

    /*
     namespace가 일치하는 기존 동기화 상태 ManagedObject를 조회합니다.

     Parameters:
     - namespace: 조회할 동기화 namespace
     - context: fetch를 수행할 context

     Returns:
     - 일치하는 ManagedObject가 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchManagedObject(
        namespace: String,
        in context: NSManagedObjectContext
    ) throws -> SyncStateRecordMO? {
        let request = SyncStateRecordMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "namespace == %@",
            namespace
        )
        return try context.fetch(request).first
    }

    /*
     저장용 동기화 상태 값을 정규화합니다.

     저장 전 namespace와 cursor 앞뒤 공백을 제거하고,
     namespace가 비어 있으면 쓰기 실패로 처리합니다.
     cursor는 정리 결과 비어 있으면 nil로 변환합니다.

     Parameters:
     - record: 호출부가 전달한 동기화 상태 값

     Returns:
     - 정규화된 동기화 상태 값

     Throws:
     - namespace가 비어 있으면 PersistenceError.writeFailed를 던집니다.
     */
    func makeNormalizedRecord(
        _ record: SyncStateRecord
    ) throws -> SyncStateRecord {
        let normalizedNamespace = normalizeValue(record.namespace)

        guard normalizedNamespace.isEmpty == false else {
            throw PersistenceError.writeFailed(
                "동기화 상태 namespace는 비어 있을 수 없습니다."
            )
        }

        return SyncStateRecord(
            namespace: normalizedNamespace,
            cursor: normalizeOptionalValue(record.cursor),
            isDirty: record.isDirty,
            lastSyncedAt: record.lastSyncedAt
        )
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
