//
//  SessionSnapshot.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation

/*
 환경별 세션 상태 1건을 표현하는 API 모델입니다.

 상위 계층은 Core Data의 ManagedObject를 직접 다루지 않고,
 이 타입을 통해 저장된 세션 상태를 읽고 저장합니다.
 이 타입은 Persistence 내부 저장 방식과 무관하게,
 환경 식별자, 로그인 여부, 마지막 갱신 시각, 사용자 식별자를 안정적으로 전달하기 위한 값 객체입니다.
 */
public struct SessionSnapshot: Equatable, Sendable {
    /* 세션 상태를 구분하는 환경 식별자입니다. */
    public let environment: String

    /* 로그인 여부입니다. */
    public let isLoggedIn: Bool

    /* 마지막으로 세션 상태를 갱신한 시각입니다. */
    public let lastRefreshedAt: Date?

    /* 로그인한 사용자 식별자입니다. */
    public let userID: String?

    /*
     세션 상태 값을 생성합니다.

     Parameters:
     - environment: 저장하거나 조회 결과로 전달할 환경 식별자
     - isLoggedIn: 저장하거나 조회 결과로 전달할 로그인 여부
     - lastRefreshedAt: 세션 상태를 마지막으로 갱신한 시각
     - userID: 로그인한 사용자 식별자. 로그아웃 상태이거나 없으면 nil을 사용할 수 있습니다.
     */
    public init(
        environment: String,
        isLoggedIn: Bool,
        lastRefreshedAt: Date?,
        userID: String?
    ) {
        self.environment = environment
        self.isLoggedIn = isLoggedIn
        self.lastRefreshedAt = lastRefreshedAt
        self.userID = userID
    }
}
