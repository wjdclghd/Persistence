//
//  CoreDataAuthSessionStore.swift
//  Persistence
//
//  Created by jch on 5/10/26.
//

import Foundation
import CoreData

/// AuthSessionStoreProtocol의 Core Data 구현체입니다.
///
/// 이 타입은 인증 세션 엔티티를 대상으로 조회, 저장, 삭제 기능을 제공합니다.
/// 토큰 원문과 토큰 만료 시각은 저장하지 않습니다.
final class CoreDataAuthSessionStore: AuthSessionStoreProtocol {
    private let coreDataStack: any CoreDataStackProtocol

    /// AuthSession Core Data 저장소를 생성합니다.
    ///
    /// - Parameters:
    ///   - coreDataStack: 인증 세션 저장에 사용할 Core Data stack 계약
    init(coreDataStack: any CoreDataStackProtocol) {
        self.coreDataStack = coreDataStack
    }

    /// 저장된 인증 세션 전체 목록을 조회합니다.
    ///
    /// - Returns: 정렬된 인증 세션 목록
    ///
    /// - Throws: 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
    func fetchAll() async throws -> [AuthSessionRecord] {
        try await coreDataStack.performRead { context in
            try self.fetchRecords(
                predicate: nil,
                in: context
            )
        }
    }

    /// 지정한 환경의 인증 세션을 조회합니다.
    ///
    /// - Parameters:
    ///   - environment: 조회할 인증 세션 환경 식별자
    ///
    /// - Returns: 일치하는 인증 세션이 있으면 반환하고, 없으면 nil을 반환합니다.
    ///
    /// - Throws: 읽기 작업이나 fetch 과정에서 오류가 발생하면 에러를 던집니다.
    func fetchSession(for environment: String) async throws -> AuthSessionRecord? {
        let normalizedEnvironment = normalizeValue(environment)

        guard normalizedEnvironment.isEmpty == false else {
            return nil
        }

        return try await coreDataStack.performRead { context in
            try self.fetchManagedObject(
                environment: normalizedEnvironment,
                in: context
            ).map(AuthSessionRecordMapper.toRecord)
        }
    }

    /// 인증 세션을 저장합니다.
    ///
    /// environment가 이미 존재하면 기존 레코드를 갱신하고,
    /// 존재하지 않으면 새 레코드를 삽입합니다.
    ///
    /// - Parameters:
    ///   - session: 저장할 인증 세션 값
    ///
    /// - Throws: 필수 값이 비어 있거나 쓰기 작업에 실패하면 에러를 던집니다.
    func save(_ session: AuthSessionRecord) async throws {
        let normalizedSession = try makeNormalizedRecord(session)

        _ = try await coreDataStack.performWrite { context in
            if let existingManagedObject = try self.fetchManagedObject(
                environment: normalizedSession.environment,
                in: context
            ) {
                AuthSessionRecordMapper.update(
                    existingManagedObject,
                    from: normalizedSession
                )
            } else {
                _ = AuthSessionRecordMapper.insert(
                    from: normalizedSession,
                    into: context
                )
            }
        }
    }

    /// 지정한 환경의 인증 세션을 삭제합니다.
    ///
    /// 전달한 environment를 앞뒤 공백 제거 후 비교하며,
    /// 일치하는 레코드가 없으면 아무 작업도 하지 않습니다.
    ///
    /// - Parameters:
    ///   - environment: 삭제할 인증 세션 환경 식별자
    ///
    /// - Throws: 삭제 작업 중 오류가 발생하면 에러를 던집니다.
    func delete(environment: String) async throws {
        let normalizedEnvironment = normalizeValue(environment)

        guard normalizedEnvironment.isEmpty == false else {
            return
        }

        _ = try await coreDataStack.performWrite { context in
            guard let managedObject = try self.fetchManagedObject(
                environment: normalizedEnvironment,
                in: context
            ) else {
                return
            }

            context.delete(managedObject)
        }
    }

    /// 저장된 인증 세션을 모두 삭제합니다.
    ///
    /// - Throws: 삭제 작업 또는 save 과정에서 오류가 발생하면 에러를 던집니다.
    func deleteAll() async throws {
        _ = try await coreDataStack.performWrite { context in
            let request = AuthSessionRecordManagedObject.fetchRequest()
            let managedObjects = try context.fetch(request)

            managedObjects.forEach(context.delete)
        }
    }
}

private extension CoreDataAuthSessionStore {
    func fetchRecords(
        predicate: NSPredicate?,
        in context: NSManagedObjectContext
    ) throws -> [AuthSessionRecord] {
        let request = AuthSessionRecordManagedObject.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(AuthSessionRecordManagedObject.environment), ascending: true)
        ]

        return try context.fetch(request).map(AuthSessionRecordMapper.toRecord)
    }

    func fetchManagedObject(
        environment: String,
        in context: NSManagedObjectContext
    ) throws -> AuthSessionRecordManagedObject? {
        let request = AuthSessionRecordManagedObject.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "environment == %@", environment)
        return try context.fetch(request).first
    }

    func makeNormalizedRecord(
        _ record: AuthSessionRecord
    ) throws -> AuthSessionRecord {
        let normalizedEnvironment = try normalizeRequiredString(
            record.environment,
            fieldName: "environment"
        )
        let normalizedEmail = try normalizeRequiredString(
            record.email,
            fieldName: "email"
        )
        let normalizedNickname = try normalizeRequiredString(
            record.nickname,
            fieldName: "nickname"
        )
        let normalizedRole = try normalizeRequiredString(
            record.role,
            fieldName: "role"
        )
        let normalizedStatus = try normalizeRequiredString(
            record.status,
            fieldName: "status"
        )

        guard record.userID > 0 else {
            throw PersistenceError.writeFailed(
                "인증 세션 userID는 1 이상이어야 합니다."
            )
        }

        return AuthSessionRecord(
            environment: normalizedEnvironment,
            userID: record.userID,
            email: normalizedEmail,
            nickname: normalizedNickname,
            role: normalizedRole,
            status: normalizedStatus,
            isLoggedIn: record.isLoggedIn,
            lastRefreshedAt: record.lastRefreshedAt
        )
    }

    func normalizeRequiredString(
        _ value: String,
        fieldName: String
    ) throws -> String {
        let normalizedValue = normalizeValue(value)

        guard normalizedValue.isEmpty == false else {
            throw PersistenceError.writeFailed(
                "인증 세션 \(fieldName)는 비어 있을 수 없습니다."
            )
        }

        return normalizedValue
    }

    func normalizeValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
