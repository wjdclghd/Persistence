//
//  SearchHistoryStoreProtocol.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation

/*
 검색 기록 저장소가 제공해야 하는 기능 계약입니다.

 상위 계층은 이 protocol을 통해 검색 기록을 조회, 저장, 삭제할 수 있으며,
 실제 Core Data 구현 세부 사항은 알 필요가 없습니다.
 검색 기록 UI는 이 계약을 기준으로 전체 목록 조회,
 입력 중 키워드 필터링,
 최근 검색 기록 저장,
 개별 삭제 및 전체 삭제 흐름을 구성할 수 있습니다.
 */
public protocol SearchHistoryStoreProtocol {
    /*
     저장된 검색 기록 전체 목록을 조회합니다.

     반환 순서
     - lastSearchedAt 내림차순
     - 같은 시각이면 keyword 오름차순

     Returns:
     - 정렬된 검색 기록 목록

     Throws:
     - 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchAll() async throws -> [SearchHistoryRecord]

    /*
     지정한 키워드를 기준으로 검색 기록을 조회합니다.

     검색 방식
     - 대소문자를 구분하지 않습니다.
     - 부분 일치로 검색합니다.
     - 공백만 전달되면 전체 목록 조회와 동일하게 동작합니다.

     Parameters:
     - keyword: 검색 기록을 필터링할 키워드

     Returns:
     - 조건에 맞는 검색 기록 목록

     Throws:
     - 읽기 작업 또는 fetch 과정에서 오류가 발생하면 에러를 던집니다.
     */
    func fetchRecords(matching keyword: String) async throws -> [SearchHistoryRecord]

    /*
     검색 기록을 저장합니다.

     저장 정책
     - keyword를 기준으로 기존 기록이 있으면 lastSearchedAt을 갱신합니다.
     - 동일 keyword가 없으면 새 레코드를 추가합니다.
     - keyword 앞뒤 공백은 정리한 뒤 저장합니다.

     Parameters:
     - record: 저장할 검색 기록 값

     Throws:
     - keyword가 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
     */
    func save(_ record: SearchHistoryRecord) async throws

    /*
     지정한 키워드의 검색 기록을 삭제합니다.

     Parameters:
     - keyword: 삭제할 검색 기록의 keyword 값

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func delete(keyword: String) async throws

    /*
     저장된 검색 기록을 모두 삭제합니다.

     Throws:
     - 삭제 작업 중 오류가 발생하면 에러를 던집니다.
     */
    func deleteAll() async throws
}
