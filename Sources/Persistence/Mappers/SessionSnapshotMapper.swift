//
//  SessionSnapshotMapper.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/// SessionSnapshot과 SessionSnapshotManagedObject 사이의 변환을 담당하는 Mapper입니다.
///
/// Persistence API는 SessionSnapshot을 외부 계약으로 사용하고,
/// Core Data 저장 계층은 SessionSnapshotManagedObject를 사용합니다.
/// 이 타입은 두 표현을 변환하여 계층 간 책임을 분리합니다.
enum SessionSnapshotMapper {
    /// ManagedObject를 공개 Record로 변환합니다.
    ///
    /// - Parameters:
    ///   - managedObject: 조회 결과로 전달받은 SessionSnapshot ManagedObject
    ///
    /// - Returns: SessionSnapshot 값 객체
    static func toSnapshot(
        _ managedObject: SessionSnapshotManagedObject
    ) -> SessionSnapshot {
        SessionSnapshot(
            environment: managedObject.environment,
            isLoggedIn: managedObject.isLoggedIn,
            lastRefreshedAt: managedObject.lastRefreshedAt,
            userID: managedObject.userID
        )
    }

    /// 공개 Record 값을 기존 ManagedObject에 반영합니다.
    ///
    /// - Parameters:
    ///   - managedObject: 값을 갱신할 SessionSnapshot ManagedObject
    ///   - snapshot: 반영할 세션 스냅샷 값
    static func update(
        _ managedObject: SessionSnapshotManagedObject,
        from snapshot: SessionSnapshot
    ) {
        managedObject.environment = snapshot.environment
        managedObject.isLoggedIn = snapshot.isLoggedIn
        managedObject.lastRefreshedAt = snapshot.lastRefreshedAt
        managedObject.userID = snapshot.userID
    }

    /// 공개 Record 값을 사용해 새 ManagedObject를 생성합니다.
    ///
    /// - Parameters:
    ///   - snapshot: 저장할 세션 스냅샷 값
    ///   - context: ManagedObject를 삽입할 context
    ///
    /// - Returns: 삽입된 SessionSnapshot ManagedObject
    static func insert(
        from snapshot: SessionSnapshot,
        into context: NSManagedObjectContext
    ) -> SessionSnapshotManagedObject {
        let managedObject = SessionSnapshotManagedObject(context: context)
        update(managedObject, from: snapshot)
        return managedObject
    }
}
