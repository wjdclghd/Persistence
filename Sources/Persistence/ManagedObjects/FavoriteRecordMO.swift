//
//  FavoriteRecordMO.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 FavoriteRecord 엔티티를 표현하는 Core Data ManagedObject입니다.

 즐겨찾기 store 구현은 이 타입을 통해 Core Data 속성에 접근하고,
 Mapper 계층은 이 타입과 FavoriteRecord 사이를 변환합니다.
 상위 계층에는 노출하지 않고 Persistence 내부에서만 사용합니다.
 */
@objc(FavoriteRecordMO)
final class FavoriteRecordMO: NSManagedObject {
    /* 즐겨찾기 대상의 식별자입니다. */
    @NSManaged var id: String

    /* 즐겨찾기 대상의 분류 타입입니다. */
    @NSManaged var type: String

    /* 즐겨찾기가 생성된 시각입니다. */
    @NSManaged var createdAt: Date
}

extension FavoriteRecordMO {
    /*
     FavoriteRecord 엔티티용 typed fetch request를 생성합니다.

     Returns:
     - FavoriteRecord 엔티티를 조회하는 NSFetchRequest
     */
    @nonobjc class func fetchRequest() -> NSFetchRequest<FavoriteRecordMO> {
        NSFetchRequest<FavoriteRecordMO>(entityName: "FavoriteRecord")
    }
}
