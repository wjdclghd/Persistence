//
//  AuthSessionRecordMapper.swift
//  Persistence
//
//  Created by jch on 5/10/26.
//

import Foundation
import CoreData

/// AuthSessionRecord와 AuthSessionRecordManagedObject 사이의 변환을 담당하는 Mapper입니다.
///
/// Persistence API는 AuthSessionRecord를 외부 계약으로 사용하고,
/// Core Data 저장 계층은 AuthSessionRecordManagedObject를 사용합니다.
enum AuthSessionRecordMapper {
    /// ManagedObject를 공개 Record로 변환합니다.
    ///
    /// - Parameters:
    ///   - managedObject: 조회 결과로 전달받은 AuthSessionRecord ManagedObject
    ///
    /// - Returns: AuthSessionRecord 값 객체
    static func toRecord(
        _ managedObject: AuthSessionRecordManagedObject
    ) -> AuthSessionRecord {
        AuthSessionRecord(
            environment: managedObject.environment,
            userID: managedObject.userID,
            email: managedObject.email,
            nickname: managedObject.nickname,
            role: managedObject.role,
            status: managedObject.status,
            isLoggedIn: managedObject.isLoggedIn,
            lastRefreshedAt: managedObject.lastRefreshedAt
        )
    }

    /// 공개 Record 값을 기존 ManagedObject에 반영합니다.
    ///
    /// - Parameters:
    ///   - managedObject: 값을 갱신할 AuthSessionRecord ManagedObject
    ///   - record: 반영할 인증 세션 값
    static func update(
        _ managedObject: AuthSessionRecordManagedObject,
        from record: AuthSessionRecord
    ) {
        managedObject.environment = record.environment
        managedObject.userID = record.userID
        managedObject.email = record.email
        managedObject.nickname = record.nickname
        managedObject.role = record.role
        managedObject.status = record.status
        managedObject.isLoggedIn = record.isLoggedIn
        managedObject.lastRefreshedAt = record.lastRefreshedAt
    }

    /// 공개 Record 값을 사용해 새 ManagedObject를 생성합니다.
    ///
    /// - Parameters:
    ///   - record: 저장할 인증 세션 값
    ///   - context: ManagedObject를 삽입할 context
    ///
    /// - Returns: 삽입된 AuthSessionRecord ManagedObject
    static func insert(
        from record: AuthSessionRecord,
        into context: NSManagedObjectContext
    ) -> AuthSessionRecordManagedObject {
        let managedObject = AuthSessionRecordManagedObject(context: context)
        update(managedObject, from: record)
        return managedObject
    }
}
