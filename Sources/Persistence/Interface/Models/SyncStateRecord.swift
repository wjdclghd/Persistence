//
//  SyncStateRecord.swift
//  Persistence
//
//  Created by jch on 3/31/26.
//

import Foundation

/*
 namespace별 동기화 상태 1건을 표현하는 API 모델입니다.

 상위 계층은 Core Data의 ManagedObject를 직접 다루지 않고,
 이 타입을 통해 저장된 동기화 상태를 읽고 저장합니다.
 이 타입은 Persistence 내부 저장 방식과 무관하게,
 namespace, 커서, dirty 여부, 마지막 동기화 시각을 안정적으로 전달하기 위한 값 객체입니다.
 */
public struct SyncStateRecord: Equatable, Sendable {
    /* 동기화 상태를 구분하는 namespace입니다. */
    public let namespace: String

    /* 다음 동기화 시작 지점을 나타내는 커서 값입니다. */
    public let cursor: String?

    /* 아직 서버와 동기화되지 않은 변경이 남아 있는지 여부입니다. */
    public let isDirty: Bool

    /* 마지막으로 동기화를 완료한 시각입니다. */
    public let lastSyncedAt: Date?

    /*
     동기화 상태 값을 생성합니다.

     Parameters:
     - namespace: 저장하거나 조회 결과로 전달할 namespace
     - cursor: 저장하거나 조회 결과로 전달할 동기화 커서 값
     - isDirty: 저장하거나 조회 결과로 전달할 dirty 여부
     - lastSyncedAt: 마지막으로 동기화를 완료한 시각
     */
    public init(
        namespace: String,
        cursor: String?,
        isDirty: Bool,
        lastSyncedAt: Date?
    ) {
        self.namespace = namespace
        self.cursor = cursor
        self.isDirty = isDirty
        self.lastSyncedAt = lastSyncedAt
    }
}
