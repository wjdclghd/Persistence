//
//  CoreDataCacheStore.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 CacheStoreProtocol의 Core Data 구현체입니다.

 이 타입은 CacheEntry 엔티티를 대상으로 조회, 저장, 삭제 기능을 제공합니다.
 상위 계층은 CacheEntry만 다루고,
 실제 Core Data fetch request 작성, upsert 처리, 삭제 작업은 이 구현체가 담당합니다.

 저장 정책
 - namespace와 key 조합을 기준으로 기존 레코드가 있으면 값을 갱신합니다.
 - 동일 조합이 없으면 새 ManagedObject를 추가합니다.
 - 저장 전 namespace, key, eTag 앞뒤 공백을 정리합니다.
 - 정리 결과 eTag가 비어 있으면 nil로 저장합니다.

 조회 정책
 - 전체 조회는 namespace 오름차순, key 오름차순으로 정렬합니다.
 - namespace별 조회는 key 오름차순으로 정렬합니다.
 - 단건 조회는 namespace와 key 정확 일치 기준으로 수행합니다.
 */
final class CoreDataCacheStore: CacheStoreProtocol {
    private let coreDataStack: CoreDataStackProtocol

    /*
     Cache Core Data 저장소를 생성합니다.

     Parameters:
     - coreDataStack: 캐시 저장에 사용할 Core Data stack 계약
     */
    init(coreDataStack: CoreDataStackProtocol) {
        self.coreDataStack = coreDataStack
    }

    /*
     저장된 캐시 항목 전체 목록을 조회합니다.

     Returns:
     - 정렬된 캐시 항목 목록

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchAll() async throws -> [CacheEntry] {
        try await coreDataStack.performRead { context in
            try self.fetchEntries(
                predicate: nil,
                sortDescriptors: [
                    NSSortDescriptor(key: #keyPath(CacheEntryMO.namespace), ascending: true),
                    NSSortDescriptor(key: #keyPath(CacheEntryMO.key), ascending: true)
                ],
                in: context
            )
        }
    }

    /*
     지정한 namespace의 캐시 항목 목록을 조회합니다.

     Parameters:
     - namespace: 조회할 캐시 namespace

     Returns:
     - 지정한 namespace에 해당하는 캐시 항목 목록

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchEntries(in namespace: String) async throws -> [CacheEntry] {
        let normalizedNamespace = normalizeValue(namespace)

        if normalizedNamespace.isEmpty {
            return try await fetchAll()
        }

        return try await coreDataStack.performRead { context in
            try self.fetchEntries(
                predicate: NSPredicate(
                    format: "namespace == %@",
                    normalizedNamespace
                ),
                sortDescriptors: [
                    NSSortDescriptor(key: #keyPath(CacheEntryMO.key), ascending: true)
                ],
                in: context
            )
        }
    }

    /*
     지정한 namespace와 key가 모두 일치하는 캐시 항목을 조회합니다.

     Parameters:
     - namespace: 조회할 캐시 namespace
     - key: 조회할 캐시 key

     Returns:
     - 일치하는 캐시 항목이 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchEntry(namespace: String, key: String) async throws -> CacheEntry? {
        let normalizedNamespace = normalizeValue(namespace)
        let normalizedKey = normalizeValue(key)

        guard normalizedNamespace.isEmpty == false, normalizedKey.isEmpty == false else {
            return nil
        }

        return try await coreDataStack.performRead { context in
            try self.fetchManagedObject(
                namespace: normalizedNamespace,
                key: normalizedKey,
                in: context
            ).map(CacheEntryMapper.toEntry)
        }
    }

    /*
     캐시 항목을 저장합니다.

     namespace와 key 조합이 이미 존재하면 기존 레코드를 갱신하고,
     존재하지 않으면 새 레코드를 삽입합니다.

     Parameters:
     - entry: 저장할 캐시 항목 값

     Throws:
     - namespace 또는 key가 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func save(_ entry: CacheEntry) async throws {
        let normalizedEntry = try makeNormalizedEntry(entry)

        _ = try await coreDataStack.performWrite { context in
            if let existingManagedObject = try self.fetchManagedObject(
                namespace: normalizedEntry.namespace,
                key: normalizedEntry.key,
                in: context
            ) {
                CacheEntryMapper.update(
                    existingManagedObject,
                    from: normalizedEntry
                )
            } else {
                _ = CacheEntryMapper.insert(
                    from: normalizedEntry,
                    into: context
                )
            }
        }
    }

    /*
     지정한 namespace와 key가 모두 일치하는 캐시 항목을 삭제합니다.

     전달한 namespace와 key를 앞뒤 공백 제거 후 비교하며,
     일치하는 레코드가 없으면 아무 작업도 하지 않습니다.

     Parameters:
     - namespace: 삭제할 캐시 namespace
     - key: 삭제할 캐시 key

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func delete(namespace: String, key: String) async throws {
        let normalizedNamespace = normalizeValue(namespace)
        let normalizedKey = normalizeValue(key)

        guard normalizedNamespace.isEmpty == false, normalizedKey.isEmpty == false else {
            return
        }

        _ = try await coreDataStack.performWrite { context in
            guard let managedObject = try self.fetchManagedObject(
                namespace: normalizedNamespace,
                key: normalizedKey,
                in: context
            ) else {
                return
            }

            context.delete(managedObject)
        }
    }

    /*
     지정한 namespace의 캐시 항목을 모두 삭제합니다.

     Parameters:
     - namespace: 삭제할 캐시 namespace

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func deleteEntries(in namespace: String) async throws {
        let normalizedNamespace = normalizeValue(namespace)

        guard normalizedNamespace.isEmpty == false else {
            return
        }

        _ = try await coreDataStack.performWrite { context in
            let request = CacheEntryMO.fetchRequest()
            request.predicate = NSPredicate(format: "namespace == %@", normalizedNamespace)
            let managedObjects = try context.fetch(request)

            managedObjects.forEach(context.delete)
        }
    }

    /*
     저장된 캐시 항목을 모두 삭제합니다.

     Throws:
     - 삭제 작업 또는 save 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func deleteAll() async throws {
        _ = try await coreDataStack.performWrite { context in
            let request = CacheEntryMO.fetchRequest()
            let managedObjects = try context.fetch(request)

            managedObjects.forEach(context.delete)
        }
    }
}

private extension CoreDataCacheStore {
    /*
     지정한 predicate와 정렬 기준으로 캐시 항목을 조회합니다.

     Parameters:
     - predicate: 조회 조건. nil이면 전체 조회를 수행합니다.
     - sortDescriptors: 조회 결과 정렬 기준
     - context: fetch를 수행할 context

     Returns:
     - 정렬된 캐시 항목 목록

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchEntries(
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        in context: NSManagedObjectContext
    ) throws -> [CacheEntry] {
        let request = CacheEntryMO.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors

        return try context.fetch(request).map(CacheEntryMapper.toEntry)
    }

    /*
     namespace와 key가 일치하는 기존 캐시 항목 ManagedObject를 조회합니다.

     Parameters:
     - namespace: 조회할 namespace 값
     - key: 조회할 key 값
     - context: fetch를 수행할 context

     Returns:
     - 일치하는 ManagedObject가 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchManagedObject(
        namespace: String,
        key: String,
        in context: NSManagedObjectContext
    ) throws -> CacheEntryMO? {
        let request = CacheEntryMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "namespace == %@", namespace),
            NSPredicate(format: "key == %@", key)
        ])
        return try context.fetch(request).first
    }

    /*
     저장용 캐시 항목을 정규화합니다.

     저장 전 namespace, key, eTag 앞뒤 공백을 제거하고,
     namespace 또는 key가 비어 있으면 쓰기 실패로 처리합니다.
     eTag는 정리 결과 비어 있으면 nil로 변환합니다.

     Parameters:
     - entry: 호출부가 전달한 캐시 항목 값

     Returns:
     - 정규화된 캐시 항목 값

     Throws:
     - namespace 또는 key가 비어 있으면 PersistenceError.writeFailed를 던집니다.
     */
    func makeNormalizedEntry(_ entry: CacheEntry) throws -> CacheEntry {
        let normalizedNamespace = normalizeValue(entry.namespace)
        let normalizedKey = normalizeValue(entry.key)

        guard normalizedNamespace.isEmpty == false else {
            throw PersistenceError.writeFailed(
                "캐시 namespace는 비어 있을 수 없습니다."
            )
        }

        guard normalizedKey.isEmpty == false else {
            throw PersistenceError.writeFailed(
                "캐시 key는 비어 있을 수 없습니다."
            )
        }

        return CacheEntry(
            namespace: normalizedNamespace,
            key: normalizedKey,
            payload: entry.payload,
            eTag: normalizeOptionalValue(entry.eTag),
            expiresAt: entry.expiresAt,
            createdAt: entry.createdAt,
            version: entry.version
        )
    }

    /*
     비교에 사용할 문자열 값을 정규화합니다.

     Parameters:
     - value: 호출부가 전달한 원본 문자열 값

     Returns:
     - 앞뒤 공백이 제거된 문자열 값
     */
    func normalizeValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /*
     선택 문자열 값을 정규화합니다.

     Parameters:
     - value: 호출부가 전달한 원본 선택 문자열 값

     Returns:
     - 앞뒤 공백 제거 후 비어 있지 않으면 정규화된 문자열을 반환하고,
       값이 없거나 비어 있으면 nil을 반환합니다.
     */
    func normalizeOptionalValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalizedValue = normalizeValue(value)
        return normalizedValue.isEmpty ? nil : normalizedValue
    }
}
