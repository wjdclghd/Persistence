//
//  SearchHistoryRecord.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation

/*
 검색 기록 1건을 표현하는 API 모델입니다.

 검색 화면이나 상위 feature 모듈은 Core Data의 ManagedObject를 직접 다루지 않고,
 이 타입을 통해 검색 기록 데이터를 읽고 저장합니다.
 이 타입은 Persistence 내부 저장 방식과 무관하게,
 검색 키워드와 마지막 검색 시각이라는 도메인 정보를 안정적으로 전달하기 위한 값 객체입니다.
 */
public struct SearchHistoryRecord: Equatable, Sendable {
    /* 사용자가 검색한 키워드입니다. */
    public let keyword: String

    /* 해당 키워드를 마지막으로 검색한 시각입니다. */
    public let lastSearchedAt: Date

    /*
     검색 기록 값을 생성합니다.

     Parameters:
     - keyword: 저장하거나 조회 결과로 전달할 검색 키워드
     - lastSearchedAt: 해당 키워드가 마지막으로 검색된 시각
     */
    public init(
        keyword: String,
        lastSearchedAt: Date
    ) {
        self.keyword = keyword
        self.lastSearchedAt = lastSearchedAt
    }
}
