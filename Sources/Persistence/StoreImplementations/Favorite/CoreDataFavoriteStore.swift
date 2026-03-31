//
//  CoreDataFavoriteStore.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 FavoriteStoreProtocol의 Core Data 구현체입니다.

 이 타입은 즐겨찾기 엔티티를 대상으로 조회, 저장, 삭제 기능을 제공합니다.
 상위 계층은 FavoriteRecord만 다루고,
 실제 Core Data fetch request 작성, upsert 처리, 삭제 작업은 이 구현체가 담당합니다.

 저장 정책
 - id와 type 조합을 기준으로 기존 레코드가 있으면 createdAt을 갱신합니다.
 - 동일 조합이 없으면 새 ManagedObject를 추가합니다.
 - 저장 전 id와 type 앞뒤 공백을 정리합니다.

 조회 정책
 - 전체 조회와 타입 필터 조회 모두 createdAt 내림차순으로 정렬합니다.
 - 같은 시각이면 type 오름차순으로 정렬합니다.
 - type도 같으면 id 오름차순으로 정렬합니다.
 */
final class CoreDataFavoriteStore: FavoriteStoreProtocol {
    private let coreDataStack: CoreDataStackProtocol

    /*
     Favorite Core Data 저장소를 생성합니다.

     Parameters:
     - coreDataStack: 즐겨찾기 저장에 사용할 Core Data stack 계약
     */
    init(coreDataStack: CoreDataStackProtocol) {
        self.coreDataStack = coreDataStack
    }

    /*
     저장된 즐겨찾기 전체 목록을 조회합니다.

     Returns:
     - 정렬된 즐겨찾기 목록

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchAll() async throws -> [FavoriteRecord] {
        try await coreDataStack.performRead { context in
            try self.fetchRecords(
                predicate: nil,
                in: context
            )
        }
    }

    /*
     지정한 타입의 즐겨찾기 목록을 조회합니다.

     Parameters:
     - type: 즐겨찾기 필터링에 사용할 타입

     Returns:
     - 지정한 타입에 해당하는 즐겨찾기 목록

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecords(ofType type: String) async throws -> [FavoriteRecord] {
        let normalizedType = normalizeValue(type)

        if normalizedType.isEmpty {
            return try await fetchAll()
        }

        return try await coreDataStack.performRead { context in
            try self.fetchRecords(
                predicate: NSPredicate(
                    format: "type == %@",
                    normalizedType
                ),
                in: context
            )
        }
    }

    /*
     지정한 식별자와 타입이 모두 일치하는 즐겨찾기를 조회합니다.

     Parameters:
     - id: 조회할 즐겨찾기 대상 식별자
     - type: 조회할 즐겨찾기 대상 타입

     Returns:
     - 일치하는 즐겨찾기가 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecord(id: String, type: String) async throws -> FavoriteRecord? {
        let normalizedID = normalizeValue(id)
        let normalizedType = normalizeValue(type)

        guard normalizedID.isEmpty == false, normalizedType.isEmpty == false else {
            return nil
        }

        return try await coreDataStack.performRead { context in
            try self.fetchManagedObject(
                id: normalizedID,
                type: normalizedType,
                in: context
            ).map(FavoriteRecordMapper.toRecord)
        }
    }

    /*
     즐겨찾기를 저장합니다.

     id와 type 조합이 이미 존재하면 기존 레코드를 갱신하고,
     존재하지 않으면 새 레코드를 삽입합니다.

     Parameters:
     - record: 저장할 즐겨찾기 값

     Throws:
     - id 또는 type이 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func save(_ record: FavoriteRecord) async throws {
        let normalizedRecord = try makeNormalizedRecord(record)

        _ = try await coreDataStack.performWrite { context in
            if let existingManagedObject = try self.fetchManagedObject(
                id: normalizedRecord.id,
                type: normalizedRecord.type,
                in: context
            ) {
                FavoriteRecordMapper.update(
                    existingManagedObject,
                    from: normalizedRecord
                )
            } else {
                _ = FavoriteRecordMapper.insert(
                    from: normalizedRecord,
                    into: context
                )
            }
        }
    }

    /*
     지정한 식별자와 타입이 모두 일치하는 즐겨찾기를 삭제합니다.

     전달한 id와 type을 앞뒤 공백 제거 후 비교하며,
     일치하는 레코드가 없으면 아무 작업도 하지 않습니다.

     Parameters:
     - id: 삭제할 즐겨찾기 대상 식별자
     - type: 삭제할 즐겨찾기 대상 타입

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func delete(id: String, type: String) async throws {
        let normalizedID = normalizeValue(id)
        let normalizedType = normalizeValue(type)

        guard normalizedID.isEmpty == false, normalizedType.isEmpty == false else {
            return
        }

        _ = try await coreDataStack.performWrite { context in
            guard let managedObject = try self.fetchManagedObject(
                id: normalizedID,
                type: normalizedType,
                in: context
            ) else {
                return
            }

            context.delete(managedObject)
        }
    }

    /*
     저장된 즐겨찾기를 모두 삭제합니다.

     Throws:
     - 삭제 작업 또는 save 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func deleteAll() async throws {
        _ = try await coreDataStack.performWrite { context in
            let request = FavoriteRecordMO.fetchRequest()
            let managedObjects = try context.fetch(request)

            managedObjects.forEach(context.delete)
        }
    }
}

private extension CoreDataFavoriteStore {
    /*
     지정한 predicate로 즐겨찾기 목록을 조회합니다.

     Parameters:
     - predicate: 조회 조건. nil이면 전체 조회를 수행합니다.
     - context: fetch를 수행할 context

     Returns:
     - 정렬된 즐겨찾기 목록

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecords(
        predicate: NSPredicate?,
        in context: NSManagedObjectContext
    ) throws -> [FavoriteRecord] {
        let request = FavoriteRecordMO.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(FavoriteRecordMO.createdAt), ascending: false),
            NSSortDescriptor(key: #keyPath(FavoriteRecordMO.type), ascending: true),
            NSSortDescriptor(key: #keyPath(FavoriteRecordMO.id), ascending: true)
        ]

        return try context.fetch(request).map(FavoriteRecordMapper.toRecord)
    }

    /*
     식별자와 타입이 모두 일치하는 기존 즐겨찾기 ManagedObject를 조회합니다.

     Parameters:
     - id: 조회할 즐겨찾기 대상 식별자
     - type: 조회할 즐겨찾기 대상 타입
     - context: fetch를 수행할 context

     Returns:
     - 일치하는 ManagedObject가 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchManagedObject(
        id: String,
        type: String,
        in context: NSManagedObjectContext
    ) throws -> FavoriteRecordMO? {
        let request = FavoriteRecordMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "id == %@ AND type == %@",
            id,
            type
        )
        return try context.fetch(request).first
    }

    /*
     저장용 즐겨찾기 값을 정규화합니다.

     저장 전 id와 type 앞뒤 공백을 제거하고,
     비어 있는 값은 쓰기 실패로 처리합니다.

     Parameters:
     - record: 호출부가 전달한 즐겨찾기 값

     Returns:
     - 정규화된 즐겨찾기 값

     Throws:
     - id 또는 type이 비어 있으면 PersistenceError.writeFailed를 던집니다.
     */
    func makeNormalizedRecord(
        _ record: FavoriteRecord
    ) throws -> FavoriteRecord {
        let normalizedID = normalizeValue(record.id)
        let normalizedType = normalizeValue(record.type)

        guard normalizedID.isEmpty == false else {
            throw PersistenceError.writeFailed(
                "즐겨찾기 id는 비어 있을 수 없습니다."
            )
        }

        guard normalizedType.isEmpty == false else {
            throw PersistenceError.writeFailed(
                "즐겨찾기 type은 비어 있을 수 없습니다."
            )
        }

        return FavoriteRecord(
            id: normalizedID,
            type: normalizedType,
            createdAt: record.createdAt
        )
    }

    /*
     비교에 사용할 문자열 값을 정규화합니다.

     Parameters:
     - value: 호출부가 전달한 원본 문자열 값

     Returns:
     - 앞뒤 공백과 줄바꿈을 제거한 문자열 값
     */
    func normalizeValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
