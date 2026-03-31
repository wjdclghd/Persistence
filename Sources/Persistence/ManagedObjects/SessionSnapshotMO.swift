//
//  SessionSnapshotMO.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/*
 SessionSnapshot 엔티티를 표현하는 Core Data ManagedObject입니다.

 세션 스냅샷 store 구현은 이 타입을 통해 Core Data 속성에 접근하고,
 Mapper 계층은 이 타입과 SessionSnapshot 사이를 변환합니다.
 상위 계층에는 노출하지 않고 Persistence 내부에서만 사용합니다.
 */
@objc(SessionSnapshotMO)
final class SessionSnapshotMO: NSManagedObject {
    /* 세션 상태를 구분하는 환경 식별자입니다. */
    @NSManaged var environment: String

    /* 로그인 여부입니다. */
    @NSManaged var isLoggedIn: Bool

    /* 마지막으로 세션 상태를 갱신한 시각입니다. */
    @NSManaged var lastRefreshedAt: Date?

    /* 로그인한 사용자 식별자입니다. */
    @NSManaged var userID: String?
}

extension SessionSnapshotMO {
    /*
     SessionSnapshot 엔티티용 typed fetch request를 생성합니다.

     Returns:
     - SessionSnapshot 엔티티를 조회하는 NSFetchRequest
     */
    @nonobjc class func fetchRequest() -> NSFetchRequest<SessionSnapshotMO> {
        NSFetchRequest<SessionSnapshotMO>(entityName: "SessionSnapshot")
    }
}
