//
//  SyncStateStoreProtocol.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation

/*
 동기화 상태 저장소가 제공해야 하는 기능 계약입니다.

 상위 계층은 이 protocol을 통해 namespace별 동기화 상태를 조회, 저장, 삭제할 수 있으며,
 실제 Core Data 구현 세부 사항은 알 필요가 없습니다.
 앱은 이 계약을 기준으로 마지막 동기화 커서 복원,
 dirty 상태 확인,
 마지막 동기화 시각 조회 같은 흐름을 구성할 수 있습니다.
 */
public protocol SyncStateStoreProtocol {
    /*
     저장된 동기화 상태 전체 목록을 조회합니다.

     반환 순서
     - namespace 오름차순

     Returns:
     - 정렬된 동기화 상태 목록

     Throws:
     - 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchAll() async throws -> [SyncStateRecord]

    /*
     지정한 namespace의 동기화 상태를 조회합니다.

     Parameters:
     - namespace: 조회할 동기화 namespace

     Returns:
     - 일치하는 동기화 상태가 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecord(for namespace: String) async throws -> SyncStateRecord?

    /*
     동기화 상태를 저장합니다.

     저장 정책
     - namespace를 기준으로 기존 기록이 있으면 값을 갱신합니다.
     - 동일 namespace가 없으면 새 레코드를 추가합니다.
     - namespace와 cursor 앞뒤 공백은 정리한 뒤 저장합니다.
     - 정리 결과 cursor가 비어 있으면 nil로 저장합니다.

     Parameters:
     - record: 저장할 동기화 상태 값

     Throws:
     - namespace가 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func save(_ record: SyncStateRecord) async throws

    /*
     지정한 namespace의 동기화 상태를 삭제합니다.

     Parameters:
     - namespace: 삭제할 동기화 namespace

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func delete(namespace: String) async throws

    /*
     저장된 동기화 상태를 모두 삭제합니다.

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func deleteAll() async throws
}
