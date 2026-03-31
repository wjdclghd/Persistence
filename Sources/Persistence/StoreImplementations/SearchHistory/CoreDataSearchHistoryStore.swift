//
//  CoreDataSearchHistoryStore.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 SearchHistoryStoreProtocol의 Core Data 구현체입니다.

 이 타입은 검색 기록 엔티티를 대상으로 조회, 저장, 삭제 기능을 제공합니다.
 상위 계층은 SearchHistoryRecord만 다루고,
 실제 Core Data fetch request 작성, upsert 처리, 삭제 작업은 이 구현체가 담당합니다.

 저장 정책
 - keyword를 기준으로 기존 레코드가 있으면 lastSearchedAt을 갱신합니다.
 - 동일 keyword가 없으면 새 ManagedObject를 추가합니다.
 - 저장 전 keyword 앞뒤 공백을 정리합니다.

 조회 정책
 - 전체 조회와 키워드 필터 조회 모두 lastSearchedAt 내림차순으로 정렬합니다.
 - 같은 시각이면 keyword 오름차순으로 정렬합니다.
 - 키워드 필터는 대소문자를 구분하지 않는 부분 일치를 사용합니다.
 */
final class CoreDataSearchHistoryStore: SearchHistoryStoreProtocol {
    private let coreDataStack: CoreDataStackProtocol

    /*
     SearchHistory Core Data 저장소를 생성합니다.

     Parameters:
     - coreDataStack: 검색 기록 저장에 사용할 Core Data stack 계약
     */
    init(coreDataStack: CoreDataStackProtocol) {
        self.coreDataStack = coreDataStack
    }

    /*
     저장된 검색 기록 전체 목록을 조회합니다.

     Returns:
     - 정렬된 검색 기록 목록

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchAll() async throws -> [SearchHistoryRecord] {
        try await coreDataStack.performRead { context in
            try self.fetchRecords(
                predicate: nil,
                in: context
            )
        }
    }

    /*
     지정한 키워드를 기준으로 검색 기록을 조회합니다.

     공백만 전달되면 전체 목록 조회와 동일하게 동작합니다.

     Parameters:
     - keyword: 검색 기록 필터링에 사용할 키워드

     Returns:
     - 조건에 맞는 검색 기록 목록

     Throws:
     - 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecords(matching keyword: String) async throws -> [SearchHistoryRecord] {
        let normalizedKeyword = normalizeSearchKeyword(keyword)

        if normalizedKeyword.isEmpty {
            return try await fetchAll()
        }

        return try await coreDataStack.performRead { context in
            try self.fetchRecords(
                predicate: NSPredicate(
                    format: "keyword CONTAINS[cd] %@",
                    normalizedKeyword
                ),
                in: context
            )
        }
    }

    /*
     검색 기록을 저장합니다.

     keyword가 이미 존재하면 기존 레코드를 갱신하고,
     존재하지 않으면 새 레코드를 삽입합니다.

     Parameters:
     - record: 저장할 검색 기록 값

     Throws:
     - keyword가 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func save(_ record: SearchHistoryRecord) async throws {
        let normalizedRecord = try makeNormalizedRecord(record)

        _ = try await coreDataStack.performWrite { context in
            if let existingManagedObject = try self.fetchManagedObject(
                keyword: normalizedRecord.keyword,
                in: context
            ) {
                SearchHistoryMapper.update(
                    existingManagedObject,
                    from: normalizedRecord
                )
            } else {
                _ = SearchHistoryMapper.insert(
                    from: normalizedRecord,
                    into: context
                )
            }
        }
    }

    /*
     지정한 키워드의 검색 기록을 삭제합니다.

     전달한 keyword를 앞뒤 공백 제거 후 비교하며,
     일치하는 레코드가 없으면 아무 작업도 하지 않습니다.

     Parameters:
     - keyword: 삭제할 검색 기록 keyword

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func delete(keyword: String) async throws {
        let normalizedKeyword = normalizeSearchKeyword(keyword)

        guard normalizedKeyword.isEmpty == false else {
            return
        }

        _ = try await coreDataStack.performWrite { context in
            guard let managedObject = try self.fetchManagedObject(
                keyword: normalizedKeyword,
                in: context
            ) else {
                return
            }

            context.delete(managedObject)
        }
    }

    /*
     저장된 검색 기록을 모두 삭제합니다.

     Throws:
     - 삭제 작업 또는 save 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func deleteAll() async throws {
        _ = try await coreDataStack.performWrite { context in
            let request = SearchHistoryMO.fetchRequest()
            let managedObjects = try context.fetch(request)

            managedObjects.forEach(context.delete)
        }
    }
}

private extension CoreDataSearchHistoryStore {
    /*
     지정한 predicate로 검색 기록을 조회합니다.

     Parameters:
     - predicate: 조회 조건. nil이면 전체 조회를 수행합니다.
     - context: fetch를 수행할 context

     Returns:
     - 정렬된 검색 기록 목록

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecords(
        predicate: NSPredicate?,
        in context: NSManagedObjectContext
    ) throws -> [SearchHistoryRecord] {
        let request = SearchHistoryMO.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(SearchHistoryMO.lastSearchedAt), ascending: false),
            NSSortDescriptor(key: #keyPath(SearchHistoryMO.keyword), ascending: true)
        ]

        return try context.fetch(request).map(SearchHistoryMapper.toRecord)
    }

    /*
     keyword가 일치하는 기존 검색 기록 ManagedObject를 조회합니다.

     Parameters:
     - keyword: 조회할 keyword 값
     - context: fetch를 수행할 context

     Returns:
     - 일치하는 ManagedObject가 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchManagedObject(
        keyword: String,
        in context: NSManagedObjectContext
    ) throws -> SearchHistoryMO? {
        let request = SearchHistoryMO.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "keyword == %@", keyword)
        return try context.fetch(request).first
    }

    /*
     저장용 검색 기록을 정규화합니다.

     저장 전 keyword 앞뒤 공백을 제거하고,
     비어 있는 값은 쓰기 실패로 처리합니다.

     Parameters:
     - record: 호출부가 전달한 검색 기록 값

     Returns:
     - 정규화된 검색 기록 값

     Throws:
     - keyword가 비어 있으면 PersistenceError.writeFailed를 던집니다.
     */
    func makeNormalizedRecord(
        _ record: SearchHistoryRecord
    ) throws -> SearchHistoryRecord {
        let normalizedKeyword = normalizeSearchKeyword(record.keyword)

        guard normalizedKeyword.isEmpty == false else {
            throw PersistenceError.writeFailed(
                "검색 기록 keyword는 비어 있을 수 없습니다."
            )
        }

        return SearchHistoryRecord(
            keyword: normalizedKeyword,
            lastSearchedAt: record.lastSearchedAt
        )
    }

    /*
     검색 또는 비교에 사용할 keyword를 정규화합니다.

     Parameters:
     - keyword: 호출부가 전달한 원본 keyword

     Returns:
     - 앞뒤 공백을 제거한 keyword
     */
    func normalizeSearchKeyword(
        _ keyword: String
    ) -> String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
