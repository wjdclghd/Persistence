//
//  SearchHistoryMO.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 SearchHistory 엔티티를 표현하는 Core Data ManagedObject입니다.

 검색 기록 store 구현은 이 타입을 통해 Core Data 속성에 접근하고,
 Mapper 계층은 이 타입과 SearchHistoryRecord 사이를 변환합니다.
 상위 계층에는 노출하지 않고 Persistence 내부에서만 사용합니다.
 */
@objc(SearchHistoryMO)
final class SearchHistoryMO: NSManagedObject {
    /* 저장된 검색 키워드입니다. */
    @NSManaged var keyword: String

    /* 마지막 검색 시각입니다. */
    @NSManaged var lastSearchedAt: Date
}

extension SearchHistoryMO {
    /*
     SearchHistory 엔티티용 typed fetch request를 생성합니다.

     Returns:
     - SearchHistory 엔티티를 조회하는 NSFetchRequest
     */
    @nonobjc class func fetchRequest() -> NSFetchRequest<SearchHistoryMO> {
        NSFetchRequest<SearchHistoryMO>(entityName: "SearchHistory")
    }
}
