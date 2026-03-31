//
//  FavoriteRecordMapper.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 FavoriteRecord와 FavoriteRecordMO 사이의 변환을 담당하는 Mapper입니다.

 Persistence API는 FavoriteRecord를 외부 계약으로 사용하고,
 Core Data 저장 계층은 FavoriteRecordMO를 사용합니다.
 이 타입은 두 표현을 변환하여 계층 간 책임을 분리합니다.
 */
enum FavoriteRecordMapper {
    /*
     ManagedObject를 API 모델로 변환합니다.

     Parameters:
     - managedObject: 조회 결과로 전달받은 FavoriteRecord ManagedObject

     Returns:
     - FavoriteRecord 값 객체
     */
    static func toRecord(
        _ managedObject: FavoriteRecordMO
    ) -> FavoriteRecord {
        FavoriteRecord(
            id: managedObject.id,
            type: managedObject.type,
            createdAt: managedObject.createdAt
        )
    }

    /*
     API 모델 값을 기존 ManagedObject에 반영합니다.

     Parameters:
     - managedObject: 값을 갱신할 FavoriteRecord ManagedObject
     - record: 반영할 즐겨찾기 값
     */
    static func update(
        _ managedObject: FavoriteRecordMO,
        from record: FavoriteRecord
    ) {
        managedObject.id = record.id
        managedObject.type = record.type
        managedObject.createdAt = record.createdAt
    }

    /*
     API 모델 값을 사용해 새 ManagedObject를 생성합니다.

     Parameters:
     - record: 저장할 즐겨찾기 값
     - context: ManagedObject를 삽입할 context

     Returns:
     - 삽입된 FavoriteRecord ManagedObject
     */
    static func insert(
        from record: FavoriteRecord,
        into context: NSManagedObjectContext
    ) -> FavoriteRecordMO {
        let managedObject = FavoriteRecordMO(context: context)
        update(managedObject, from: record)
        return managedObject
    }
}
