//
//  SessionSnapshotStoreProtocol.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation
/*
 세션 스냅샷 저장소가 제공해야 하는 기능 계약입니다.

 상위 계층은 이 protocol을 통해 환경별 세션 스냅샷을 조회, 저장, 삭제할 수 있으며,
 실제 Core Data 구현 세부 사항은 알 필요가 없습니다.
 앱은 이 계약을 기준으로 현재 세션 상태 복원,
 환경별 로그인 여부 확인,
 마지막 사용자 정보 조회 같은 흐름을 구성할 수 있습니다.
 */
public protocol SessionSnapshotStoreProtocol {
    /*
     저장된 세션 스냅샷 전체 목록을 조회합니다.

     반환 순서
     - environment 오름차순

     Returns:
     - 정렬된 세션 스냅샷 목록

     Throws:
     - 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchAll() async throws -> [SessionSnapshot]

    /*
     지정한 환경의 세션 스냅샷을 조회합니다.

     Parameters:
     - environment: 조회할 세션 환경 식별자

     Returns:
     - 일치하는 세션 스냅샷이 있으면 반환하고, 없으면 nil을 반환합니다.

     Throws:
     - 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchSnapshot(for environment: String) async throws -> SessionSnapshot?

    /*
     세션 스냅샷을 저장합니다.

     저장 정책
     - environment를 기준으로 기존 기록이 있으면 값을 갱신합니다.
     - 동일 environment가 없으면 새 레코드를 추가합니다.
     - environment와 userID 앞뒤 공백은 정리한 뒤 저장합니다.
     - 정리 결과 userID가 비어 있으면 nil로 저장합니다.

     Parameters:
     - snapshot: 저장할 세션 스냅샷 값

     Throws:
     - environment가 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func save(_ snapshot: SessionSnapshot) async throws

    /*
     지정한 환경의 세션 스냅샷을 삭제합니다.

     Parameters:
     - environment: 삭제할 세션 환경 식별자

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func delete(environment: String) async throws

    /*
     저장된 세션 스냅샷을 모두 삭제합니다.

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func deleteAll() async throws
}
