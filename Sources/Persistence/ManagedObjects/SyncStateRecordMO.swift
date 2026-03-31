//
//  SyncStateRecordMO.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 SyncStateRecord 엔티티를 표현하는 Core Data ManagedObject입니다.

 동기화 상태 store 구현은 이 타입을 통해 Core Data 속성에 접근하고,
 Mapper 계층은 이 타입과 SyncStateRecord 사이를 변환합니다.
 상위 계층에는 노출하지 않고 Persistence 내부에서만 사용합니다.
 */
@objc(SyncStateRecordMO)
final class SyncStateRecordMO: NSManagedObject {
    /* 동기화 상태를 구분하는 namespace입니다. */
    @NSManaged var namespace: String

    /* 다음 동기화 시작 지점을 나타내는 커서 값입니다. */
    @NSManaged var cursor: String?

    /* 아직 서버와 동기화되지 않은 변경이 남아 있는지 여부입니다. */
    @NSManaged var isDirty: Bool

    /* 마지막으로 동기화를 완료한 시각입니다. */
    @NSManaged var lastSyncedAt: Date?
}

extension SyncStateRecordMO {
    /*
     SyncStateRecord 엔티티용 typed fetch request를 생성합니다.

     Returns:
     - SyncStateRecord 엔티티를 조회하는 NSFetchRequest
     */
    @nonobjc class func fetchRequest() -> NSFetchRequest<SyncStateRecordMO> {
        NSFetchRequest<SyncStateRecordMO>(entityName: "SyncStateRecord")
    }
}
