//
//  CacheEntryMapper.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
import CoreData

/// CacheEntry와 CacheEntryManagedObject 사이의 변환을 담당하는 Mapper입니다.
///
/// Persistence API는 CacheEntry를 외부 계약으로 사용하고,
/// Core Data 저장 계층은 CacheEntryManagedObject를 사용합니다.
/// 이 타입은 두 표현을 변환하여 계층 간 책임을 분리합니다.
enum CacheEntryMapper {
    /// ManagedObject를 공개 Record로 변환합니다.
    ///
    /// - Parameters:
    ///   - managedObject: 조회 결과로 전달받은 CacheEntry ManagedObject
    ///
    /// - Returns: CacheEntry 값 객체
    static func toEntry(_ managedObject: CacheEntryManagedObject) -> CacheEntry {
        CacheEntry(
            namespace: managedObject.namespace,
            key: managedObject.key,
            payload: managedObject.payload,
            eTag: managedObject.eTag,
            expiresAt: managedObject.expiresAt,
            createdAt: managedObject.createdAt,
            version: managedObject.version
        )
    }

    /// 공개 Record 값을 기존 ManagedObject에 반영합니다.
    ///
    /// - Parameters:
    ///   - managedObject: 값을 갱신할 CacheEntry ManagedObject
    ///   - entry: 반영할 캐시 항목 값
    static func update(
        _ managedObject: CacheEntryManagedObject,
        from entry: CacheEntry
    ) {
        managedObject.namespace = entry.namespace
        managedObject.key = entry.key
        managedObject.payload = entry.payload
        managedObject.eTag = entry.eTag
        managedObject.expiresAt = entry.expiresAt
        managedObject.createdAt = entry.createdAt
        managedObject.version = entry.version
    }

    /// 공개 Record 값을 사용해 새 ManagedObject를 생성합니다.
    ///
    /// - Parameters:
    ///   - entry: 저장할 캐시 항목 값
    ///   - context: ManagedObject를 삽입할 context
    ///
    /// - Returns: 삽입된 CacheEntry ManagedObject
    static func insert(
        from entry: CacheEntry,
        into context: NSManagedObjectContext
    ) -> CacheEntryManagedObject {
        let managedObject = CacheEntryManagedObject(context: context)
        update(managedObject, from: entry)
        return managedObject
    }
}
