//
//  CacheEntryMO.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 CacheEntry 엔티티를 표현하는 Core Data ManagedObject입니다.

 캐시 store 구현은 이 타입을 통해 Core Data 속성에 접근하고,
 Mapper 계층은 이 타입과 CacheEntry 사이를 변환합니다.
 상위 계층에는 노출하지 않고 Persistence 내부에서만 사용합니다.
 */
@objc(CacheEntryMO)
final class CacheEntryMO: NSManagedObject {
    /* 캐시 항목을 구분하는 namespace입니다. */
    @NSManaged var namespace: String

    /* namespace 내부에서 항목을 구분하는 key입니다. */
    @NSManaged var key: String

    /* 저장된 캐시 payload입니다. */
    @NSManaged var payload: Data

    /* 서버 캐시 검증에 사용할 eTag입니다. */
    @NSManaged var eTag: String?

    /* 캐시 만료 시각입니다. */
    @NSManaged var expiresAt: Date?

    /* 캐시 항목이 생성된 시각입니다. */
    @NSManaged var createdAt: Date

    /* 캐시 항목 버전입니다. */
    @NSManaged var version: Int64
}

extension CacheEntryMO {
    /*
     CacheEntry 엔티티용 typed fetch request를 생성합니다.

     Returns:
     - CacheEntry 엔티티를 조회하는 NSFetchRequest
     */
    @nonobjc class func fetchRequest() -> NSFetchRequest<CacheEntryMO> {
        NSFetchRequest<CacheEntryMO>(entityName: "CacheEntry")
    }
}
