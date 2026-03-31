//
//  FavoriteStoreProtocol.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation

/*
 즐겨찾기 저장소가 제공해야 하는 기능 계약입니다.

 상위 계층은 이 protocol을 통해 즐겨찾기 목록을 조회, 저장, 삭제할 수 있으며,
 실제 Core Data 구현 세부 사항은 알 필요가 없습니다.
 즐겨찾기 UI는 이 계약을 기준으로 전체 목록 조회,
 타입별 목록 조회,
 특정 항목 확인,
 즐겨찾기 저장과 삭제 흐름을 구성할 수 있습니다.
 */
public protocol FavoriteStoreProtocol {
    /*
     저장된 즐겨찾기 전체 목록을 조회합니다.

     반환 순서
     - createdAt 내림차순
     - 같은 시각이면 type 오름차순
     - type도 같으면 id 오름차순

     Returns:
     - 정렬된 즐겨찾기 목록

     Throws:
     - 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchAll() async throws -> [FavoriteRecord]

    /*
     지정한 타입의 즐겨찾기 목록을 조회합니다.

     Parameters:
     - type: 조회할 즐겨찾기 대상 타입

     Returns:
     - 지정한 타입에 해당하는 즐겨찾기 목록

     Throws:
     - 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecords(ofType type: String) async throws -> [FavoriteRecord]

    /*
     지정한 식별자와 타입이 모두 일치하는 즐겨찾기를 조회합니다.

     Parameters:
     - id: 조회할 즐겨찾기 대상 식별자
     - type: 조회할 즐겨찾기 대상 타입

     Returns:
     - 일치하는 즐겨찾기가 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecord(id: String, type: String) async throws -> FavoriteRecord?

    /*
     즐겨찾기를 저장합니다.

     저장 정책
     - id와 type 조합을 기준으로 기존 기록이 있으면 createdAt을 갱신합니다.
     - 동일 조합이 없으면 새 레코드를 추가합니다.
     - id와 type 앞뒤 공백은 정리한 뒤 저장합니다.

     Parameters:
     - record: 저장할 즐겨찾기 값

     Throws:
     - id 또는 type이 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func save(_ record: FavoriteRecord) async throws

    /*
     지정한 식별자와 타입이 모두 일치하는 즐겨찾기를 삭제합니다.

     Parameters:
     - id: 삭제할 즐겨찾기 대상 식별자
     - type: 삭제할 즐겨찾기 대상 타입

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func delete(id: String, type: String) async throws

    /*
     저장된 즐겨찾기를 모두 삭제합니다.

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func deleteAll() async throws
}
