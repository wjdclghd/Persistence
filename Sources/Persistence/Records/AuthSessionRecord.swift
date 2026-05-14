//
//  AuthSessionRecord.swift
//  Persistence
//
//  Created by jch on 5/10/26.
//

import Foundation

/// 인증 세션 1건을 표현하는 공개 Record입니다.
///
/// 로그인 또는 토큰 재발급 응답의 사용자 기본 정보를 로컬에 저장할 때 사용합니다.
/// 토큰 원문과 토큰 만료 시각은 저장하지 않습니다.
public struct AuthSessionRecord: Equatable, Sendable {
    /// 인증 세션을 구분하는 환경 식별자입니다.
    public let environment: String

    /// 로그인한 사용자 식별자입니다.
    public let userID: Int64

    /// 로그인한 사용자 이메일입니다.
    public let email: String

    /// 로그인한 사용자 닉네임입니다.
    public let nickname: String

    /// 로그인한 사용자 역할입니다.
    public let role: String

    /// 로그인한 사용자 상태입니다.
    public let status: String

    /// 로컬 인증 세션의 로그인 여부입니다.
    public let isLoggedIn: Bool

    /// 인증 세션을 마지막으로 갱신한 시각입니다.
    public let lastRefreshedAt: Date

    /// 인증 세션 값을 생성합니다.
    ///
    /// - Parameters:
    ///   - environment: 저장하거나 조회 결과로 전달할 환경 식별자
    ///   - userID: 로그인한 사용자 식별자
    ///   - email: 로그인한 사용자 이메일
    ///   - nickname: 로그인한 사용자 닉네임
    ///   - role: 로그인한 사용자 역할
    ///   - status: 로그인한 사용자 상태
    ///   - isLoggedIn: 로컬 인증 세션의 로그인 여부
    ///   - lastRefreshedAt: 인증 세션을 마지막으로 갱신한 시각
    public init(
        environment: String,
        userID: Int64,
        email: String,
        nickname: String,
        role: String,
        status: String,
        isLoggedIn: Bool,
        lastRefreshedAt: Date
    ) {
        self.environment = environment
        self.userID = userID
        self.email = email
        self.nickname = nickname
        self.role = role
        self.status = status
        self.isLoggedIn = isLoggedIn
        self.lastRefreshedAt = lastRefreshedAt
    }
}
