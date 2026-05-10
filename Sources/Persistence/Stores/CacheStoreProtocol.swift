//
//  CacheStoreProtocol.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation

/// 캐시 저장소가 제공해야 하는 기능 계약입니다.
///
/// 상위 계층은 이 protocol을 통해 namespace별 캐시 항목을 조회, 저장, 삭제할 수 있으며,
/// 실제 Core Data 구현 세부 사항은 알 필요가 없습니다.
/// 캐시 계층은 이 계약을 기준으로 단건 조회,
/// namespace별 목록 조회,
/// 전체 캐시 정리 흐름을 구성할 수 있습니다.
public protocol CacheStoreProtocol {
    /// 저장된 캐시 항목 전체 목록을 조회합니다.
    ///
    /// 반환 순서
    /// - namespace 오름차순
    /// - 같은 namespace이면 key 오름차순
    ///
    /// - Returns: 정렬된 캐시 항목 목록
    ///
    /// - Throws: 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
    func fetchAll() async throws -> [CacheEntry]

    /// 지정한 namespace의 캐시 항목 목록을 조회합니다.
    ///
    /// - Parameters:
    ///   - namespace: 조회할 캐시 namespace
    ///
    /// - Returns: 지정한 namespace에 해당하는 캐시 항목 목록
    ///
    /// - Throws: 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
    func fetchEntries(in namespace: String) async throws -> [CacheEntry]

    /// 지정한 namespace와 key가 모두 일치하는 캐시 항목을 조회합니다.
    ///
    /// - Parameters:
    ///   - namespace: 조회할 캐시 namespace
    ///   - key: 조회할 캐시 key
    ///
    /// - Returns: 일치하는 캐시 항목이 있으면 반환하고, 없으면 nil을 반환합니다.
    ///
    /// - Throws: 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
    func fetchEntry(namespace: String, key: String) async throws -> CacheEntry?

    /// 캐시 항목을 저장합니다.
    ///
    /// 저장 정책
    /// - namespace와 key 조합을 기준으로 기존 기록이 있으면 값을 갱신합니다.
    /// - 동일 조합이 없으면 새 레코드를 추가합니다.
    /// - namespace, key, eTag 앞뒤 공백은 정리한 뒤 저장합니다.
    /// - 정리 결과 eTag가 비어 있으면 nil로 저장합니다.
    ///
    /// - Parameters:
    ///   - entry: 저장할 캐시 항목 값
    ///
    /// - Throws: namespace 또는 key가 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
    func save(_ entry: CacheEntry) async throws

    /// 지정한 namespace와 key가 모두 일치하는 캐시 항목을 삭제합니다.
    ///
    /// - Parameters:
    ///   - namespace: 삭제할 캐시 namespace
    ///   - key: 삭제할 캐시 key
    ///
    /// - Throws: 삭제 작업 중 오류가 발생하면 에러를 던집니다.
    func delete(namespace: String, key: String) async throws

    /// 지정한 namespace의 캐시 항목을 모두 삭제합니다.
    ///
    /// - Parameters:
    ///   - namespace: 삭제할 캐시 namespace
    ///
    /// - Throws: 삭제 작업 중 오류가 발생하면 에러를 던집니다.
    func deleteEntries(in namespace: String) async throws

    /// 저장된 캐시 항목을 모두 삭제합니다.
    ///
    /// - Throws: 삭제 작업 중 오류가 발생하면 에러를 던집니다.
    func deleteAll() async throws
}
