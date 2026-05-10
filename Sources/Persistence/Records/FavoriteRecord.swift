//
//  FavoriteRecord.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation

/// 즐겨찾기 1건을 표현하는 공개 Record입니다.
///
/// 상위 계층은 Core Data의 ManagedObject를 직접 다루지 않고,
/// 이 타입을 통해 즐겨찾기 데이터를 읽고 저장합니다.
/// 이 타입은 Persistence 내부 저장 방식과 무관하게,
/// 식별자, 타입, 생성 시각이라는 도메인 정보를 안정적으로 전달하기 위한 값 객체입니다.
public struct FavoriteRecord: Equatable, Sendable {
    /// 즐겨찾기 대상의 식별자입니다.
    public let id: String

    /// 즐겨찾기 대상의 분류 타입입니다.
    public let type: String

    /// 즐겨찾기가 생성된 시각입니다.
    public let createdAt: Date

    /// 즐겨찾기 값을 생성합니다.
    ///
    /// - Parameters:
    ///   - id: 저장하거나 조회 결과로 전달할 즐겨찾기 대상 식별자
    ///   - type: 저장하거나 조회 결과로 전달할 즐겨찾기 대상 타입
    ///   - createdAt: 즐겨찾기가 생성된 시각
    public init(
        id: String,
        type: String,
        createdAt: Date
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
    }
}
