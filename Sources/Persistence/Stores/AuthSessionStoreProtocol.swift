//
//  AuthSessionStoreProtocol.swift
//  Persistence
//
//  Created by jch on 5/10/26.
//

import Foundation

/// 인증 세션 저장소가 제공해야 하는 기능 계약입니다.
///
/// 상위 계층은 이 protocol을 통해 로그인 사용자 기본 정보를 조회, 저장, 삭제할 수 있으며,
/// 실제 Core Data 구현 세부 사항은 알 필요가 없습니다.
public protocol AuthSessionStoreProtocol {
    /// 저장된 인증 세션 전체 목록을 조회합니다.
    ///
    /// 반환 순서
    /// - environment 오름차순
    ///
    /// - Returns: 정렬된 인증 세션 목록
    ///
    /// - Throws: 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
    func fetchAll() async throws -> [AuthSessionRecord]

    /// 지정한 환경의 인증 세션을 조회합니다.
    ///
    /// - Parameters:
    ///   - environment: 조회할 인증 세션 환경 식별자
    ///
    /// - Returns: 일치하는 인증 세션이 있으면 반환하고, 없으면 nil을 반환합니다.
    ///
    /// - Throws: 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
    func fetchSession(for environment: String) async throws -> AuthSessionRecord?

    /// 인증 세션을 저장합니다.
    ///
    /// 저장 정책
    /// - environment를 기준으로 기존 기록이 있으면 값을 갱신합니다.
    /// - 동일 environment가 없으면 새 레코드를 추가합니다.
    /// - 문자열 값은 앞뒤 공백을 정리한 뒤 저장합니다.
    ///
    /// - Parameters:
    ///   - session: 저장할 인증 세션 값
    ///
    /// - Throws: 필수 값이 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
    func save(_ session: AuthSessionRecord) async throws

    /// 지정한 환경의 인증 세션을 삭제합니다.
    ///
    /// - Parameters:
    ///   - environment: 삭제할 인증 세션 환경 식별자
    ///
    /// - Throws: 삭제 작업 중 오류가 발생하면 에러를 던집니다.
    func delete(environment: String) async throws

    /// 저장된 인증 세션을 모두 삭제합니다.
    ///
    /// - Throws: 삭제 작업 중 오류가 발생하면 에러를 던집니다.
    func deleteAll() async throws
}
