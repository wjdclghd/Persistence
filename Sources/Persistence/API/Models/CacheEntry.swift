//
//  CacheEntry.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation

/*
 캐시 항목 1건을 표현하는 API 모델입니다.

 상위 계층은 Core Data의 ManagedObject를 직접 다루지 않고,
 이 타입을 통해 캐시 데이터를 읽고 저장합니다.
 이 타입은 Persistence 내부 저장 방식과 무관하게,
 namespace, key, payload, 만료 시각, 버전 같은 캐시 정보를 안정적으로 전달하기 위한 값 객체입니다.
 */
public struct CacheEntry: Equatable, Sendable {
    /* 캐시 항목을 구분하는 namespace입니다. */
    public let namespace: String

    /* namespace 내부에서 항목을 구분하는 key입니다. */
    public let key: String

    /* 저장된 캐시 payload입니다. */
    public let payload: Data

    /* 서버 캐시 검증에 사용할 eTag입니다. */
    public let eTag: String?

    /* 캐시 만료 시각입니다. 만료 정책이 없으면 nil일 수 있습니다. */
    public let expiresAt: Date?

    /* 캐시 항목이 생성된 시각입니다. */
    public let createdAt: Date

    /* 캐시 항목 버전입니다. */
    public let version: Int64

    /*
     캐시 항목 값을 생성합니다.

     Parameters:
     - namespace: 저장하거나 조회 결과로 전달할 cache namespace
     - key: 저장하거나 조회 결과로 전달할 cache key
     - payload: 저장하거나 조회 결과로 전달할 cache payload
     - eTag: 캐시 검증에 사용할 eTag. 값이 없으면 nil을 사용할 수 있습니다.
     - expiresAt: 캐시 만료 시각. 값이 없으면 nil을 사용할 수 있습니다.
     - createdAt: 캐시 항목이 생성된 시각
     - version: 캐시 항목 버전
     */
    public init(
        namespace: String,
        key: String,
        payload: Data,
        eTag: String?,
        expiresAt: Date?,
        createdAt: Date,
        version: Int64
    ) {
        self.namespace = namespace
        self.key = key
        self.payload = payload
        self.eTag = eTag
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.version = version
    }
}
