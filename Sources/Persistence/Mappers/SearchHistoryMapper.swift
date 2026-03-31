//
//  File.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 SearchHistoryRecord와 SearchHistoryMO 사이의 변환을 담당하는 Mapper입니다.

 Persistence API는 SearchHistoryRecord를 외부 계약으로 사용하고,
 Core Data 저장 계층은 SearchHistoryMO를 사용합니다.
 이 타입은 두 표현을 변환하여 계층 간 책임을 분리합니다.
 */
enum SearchHistoryMapper {
    /*
     ManagedObject를 API 모델로 변환합니다.

     Parameters:
     - managedObject: 조회 결과로 전달받은 SearchHistory ManagedObject

     Returns:
     - SearchHistoryRecord 값 객체
     */
    static func toRecord(
        _ managedObject: SearchHistoryMO
    ) -> SearchHistoryRecord {
        SearchHistoryRecord(
            keyword: managedObject.keyword,
            lastSearchedAt: managedObject.lastSearchedAt
        )
    }

    /*
     API 모델 값을 기존 ManagedObject에 반영합니다.

     Parameters:
     - managedObject: 값을 갱신할 SearchHistory ManagedObject
     - record: 반영할 검색 기록 값
     */
    static func update(
        _ managedObject: SearchHistoryMO,
        from record: SearchHistoryRecord
    ) {
        managedObject.keyword = record.keyword
        managedObject.lastSearchedAt = record.lastSearchedAt
    }

    /*
     API 모델 값을 사용해 새 ManagedObject를 생성합니다.

     Parameters:
     - record: 저장할 검색 기록 값
     - context: ManagedObject를 삽입할 context

     Returns:
     - 삽입된 SearchHistory ManagedObject
     */
    static func insert(
        from record: SearchHistoryRecord,
        into context: NSManagedObjectContext
    ) -> SearchHistoryMO {
        let managedObject = SearchHistoryMO(context: context)
        update(managedObject, from: record)
        return managedObject
    }
}
