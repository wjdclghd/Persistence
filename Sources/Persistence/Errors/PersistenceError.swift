//
//  PersistenceError.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation

/// Persistence 모듈 전반에서 공통으로 사용하는 에러 타입입니다.
///
/// 이 타입은 저장소 초기화, Core Data 모델 로딩, persistent store 연결,
/// background context 기반 읽기/쓰기 실행 과정에서 발생할 수 있는 실패를
/// 하나의 도메인으로 정리하기 위해 사용합니다.
///
/// 상위 계층은 Foundation 또는 Core Data의 구체적인 에러 타입을 직접 해석하지 않고,
/// 이 타입을 기준으로 실패 원인을 분류할 수 있습니다.
public enum PersistenceError: Error, LocalizedError {
    /// Persistence 구성을 만들기 위한 값이 올바르지 않거나,
    /// 실행에 필요한 필수 정보가 누락된 경우 발생합니다.
    ///
    /// - Parameter String: 잘못된 설정 내용 또는 누락된 항목을 설명하는 메시지입니다.
    case invalidConfiguration(String)

    /// 지정한 이름의 Core Data 모델을 번들에서 찾지 못한 경우 발생합니다.
    ///
    /// 일반적으로 모델 파일명, 번들 지정, 리소스 포함 설정이 맞지 않을 때 사용합니다.
    ///
    /// - Parameters:
    ///   - modelName: 찾으려는 Core Data 모델 이름입니다.
    ///   - bundlePath: 모델 탐색을 시도한 번들 경로입니다.
    case modelNotFound(modelName: String, bundlePath: String)

    /// NSPersistentContainer가 persistent store를 로드하지 못한 경우 발생합니다.
    ///
    /// SQLite 파일 접근 문제, 스토어 메타데이터 불일치, 마이그레이션 실패,
    /// 파일 시스템 권한 문제 등 저장소 연결 단계의 실패를 표현합니다.
    ///
    /// - Parameter String: persistent store 로딩 실패 원인을 설명하는 메시지입니다.
    case persistentStoreLoadFailed(String)

    /// background context에서 읽기 작업을 수행하는 중 실패한 경우 발생합니다.
    ///
    /// fetch 실행, context 접근, 객체 변환 과정에서 발생한 오류를
    /// 읽기 작업 실패로 묶어 표현합니다.
    ///
    /// - Parameter String: 읽기 작업 실패 원인을 설명하는 메시지입니다.
    case readFailed(String)

    /// background context에서 쓰기 작업 또는 save 단계가 실패한 경우 발생합니다.
    ///
    /// insert, update, delete 이후 context 저장 중 발생한 오류를 포함하며,
    /// 데이터 반영이 완료되지 않았음을 나타냅니다.
    ///
    /// - Parameter String: 쓰기 작업 또는 저장 실패 원인을 설명하는 메시지입니다.
    case writeFailed(String)

    /// 사용자 표시용 에러 설명을 제공합니다.
    ///
    /// 로깅, 디버깅, 상위 계층 전달 시 실패 원인을
    /// 일관된 문장으로 확인할 수 있도록 구성합니다.
    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message):
            return "Persistence 설정이 올바르지 않습니다. \(message)"

        case let .modelNotFound(modelName, bundlePath):
            return "Core Data 모델을 찾을 수 없습니다. modelName: \(modelName), bundlePath: \(bundlePath)"

        case let .persistentStoreLoadFailed(message):
            return "Persistent Store를 불러오지 못했습니다. \(message)"

        case let .readFailed(message):
            return "읽기 작업에 실패했습니다. \(message)"

        case let .writeFailed(message):
            return "쓰기 작업에 실패했습니다. \(message)"
        }
    }
}
