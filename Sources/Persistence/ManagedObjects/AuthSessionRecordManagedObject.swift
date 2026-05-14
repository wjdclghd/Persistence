//
//  AuthSessionRecordManagedObject.swift
//  Persistence
//
//  Created by jch on 5/10/26.
//

import Foundation
import CoreData

/// AuthSessionRecord 엔티티를 표현하는 Core Data ManagedObject입니다.
///
/// 인증 세션 store 구현은 이 타입을 통해 Core Data 속성에 접근하고,
/// Mapper 계층은 이 타입과 AuthSessionRecord 사이를 변환합니다.
@objc(AuthSessionRecordManagedObject)
final class AuthSessionRecordManagedObject: NSManagedObject {
    /// 인증 세션을 구분하는 환경 식별자입니다.
    @NSManaged var environment: String

    /// 로그인한 사용자 식별자입니다.
    @NSManaged var userID: Int64

    /// 로그인한 사용자 이메일입니다.
    @NSManaged var email: String

    /// 로그인한 사용자 닉네임입니다.
    @NSManaged var nickname: String

    /// 로그인한 사용자 역할입니다.
    @NSManaged var role: String

    /// 로그인한 사용자 상태입니다.
    @NSManaged var status: String

    /// 로컬 인증 세션의 로그인 여부입니다.
    @NSManaged var isLoggedIn: Bool

    /// 인증 세션을 마지막으로 갱신한 시각입니다.
    @NSManaged var lastRefreshedAt: Date
}

extension AuthSessionRecordManagedObject {
    /// AuthSessionRecord 엔티티용 typed fetch request를 생성합니다.
    ///
    /// - Returns: AuthSessionRecord 엔티티를 조회하는 NSFetchRequest
    @nonobjc class func fetchRequest() -> NSFetchRequest<AuthSessionRecordManagedObject> {
        NSFetchRequest<AuthSessionRecordManagedObject>(entityName: "AuthSessionRecord")
    }
}
