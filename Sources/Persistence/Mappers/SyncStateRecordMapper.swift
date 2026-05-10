//
//  SyncStateRecordMapper.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/// SyncStateRecord와 SyncStateRecordManagedObject 사이의 변환을 담당하는 Mapper입니다.
///
/// Persistence API는 SyncStateRecord를 외부 계약으로 사용하고,
/// Core Data 저장 계층은 SyncStateRecordManagedObject를 사용합니다.
/// 이 타입은 두 표현을 변환하여 계층 간 책임을 분리합니다.
enum SyncStateRecordMapper {
    /// ManagedObject를 공개 Record로 변환합니다.
    ///
    /// - Parameters:
    ///   - managedObject: 조회 결과로 전달받은 SyncStateRecord ManagedObject
    ///
    /// - Returns: SyncStateRecord 값 객체
    static func toRecord(
        _ managedObject: SyncStateRecordManagedObject
    ) -> SyncStateRecord {
        SyncStateRecord(
            namespace: managedObject.namespace,
            cursor: managedObject.cursor,
            isDirty: managedObject.isDirty,
            lastSyncedAt: managedObject.lastSyncedAt
        )
    }

    /// 공개 Record 값을 기존 ManagedObject에 반영합니다.
    ///
    /// - Parameters:
    ///   - managedObject: 값을 갱신할 SyncStateRecord ManagedObject
    ///   - record: 반영할 동기화 상태 값
    static func update(
        _ managedObject: SyncStateRecordManagedObject,
        from record: SyncStateRecord
    ) {
        managedObject.namespace = record.namespace
        managedObject.cursor = record.cursor
        managedObject.isDirty = record.isDirty
        managedObject.lastSyncedAt = record.lastSyncedAt
    }

    /// 공개 Record 값을 사용해 새 ManagedObject를 생성합니다.
    ///
    /// - Parameters:
    ///   - record: 저장할 동기화 상태 값
    ///   - context: ManagedObject를 삽입할 context
    ///
    /// - Returns: 삽입된 SyncStateRecord ManagedObject
    static func insert(
        from record: SyncStateRecord,
        into context: NSManagedObjectContext
    ) -> SyncStateRecordManagedObject {
        let managedObject = SyncStateRecordManagedObject(context: context)
        update(managedObject, from: record)
        return managedObject
    }
}
