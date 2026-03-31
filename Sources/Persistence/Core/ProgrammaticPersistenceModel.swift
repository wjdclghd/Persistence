//
//  ProgrammaticPersistenceModel.swift
//  Persistence
//
//  Created by jch on 3/29/26.
//

import Foundation
import CoreData

/*
 코드로 NSManagedObjectModel을 구성하는 예시 모델입니다.

 이 타입은 Persistence 리소스 번들에 포함된 기본 엔티티 구성을
 동일한 이름으로 재현할 수 있도록 도와줍니다.

 사용 목적
 - .xcdatamodeld 없이 동작하는 실험용 모델 구성
 - 테스트에서 리소스 번들 의존성 제거
 - 모델 구조를 코드로 비교하거나 검증하는 용도
 - PersistenceConfiguration.ManagedObjectModelSource.programmatic에 전달할 기본 모델 생성
 */
public enum ProgrammaticPersistenceModel {
    /*
     Persistence 모듈의 기본 엔티티 구성을 포함한 NSManagedObjectModel을 생성합니다.

     생성되는 엔티티 이름과 속성 이름은 기본 번들 모델과 동일한 값을 사용하므로,
     동일한 fetch 요청과 키 경로를 유지하면서 모델 공급 방식만 바꿔서 실험할 수 있습니다.
     */
    public static func makeDefaultModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            makeSearchHistoryRecordEntity(),
            makeFavoriteRecordEntity(),
            makeSessionSnapshotEntity(),
            makeCacheEntryEntity(),
            makeSyncStateRecordEntity()
        ]
        return model
    }

    /*
     PersistenceConfiguration에서 바로 사용할 수 있는 기본 modelSource를 반환합니다.

     Returns:
     - 기본 programmatic 모델을 생성하는 ManagedObjectModelSource
     */
    public static func defaultSource(
        modelName: String = "PersistenceModel"
    ) -> PersistenceConfiguration.ManagedObjectModelSource {
        .programmatic(
            modelName: modelName,
            makeManagedObjectModel: {
                makeDefaultModel()
            }
        )
    }
}

private extension ProgrammaticPersistenceModel {
    /*
     SearchHistoryRecord 엔티티를 생성합니다.

     검색 키워드와 마지막 검색 시각을 저장하며,
     SearchHistoryRecordMO를 represented class로 사용합니다.
     keyword를 uniqueness constraint로 사용합니다.
     */
    static func makeSearchHistoryRecordEntity() -> NSEntityDescription {
        let entity = makeEntity(
            named: "SearchHistoryRecord",
            managedObjectClassName: NSStringFromClass(SearchHistoryRecordMO.self)
        )
        entity.properties = [
            makeStringAttribute(named: "keyword", isOptional: false),
            makeDateAttribute(named: "lastSearchedAt", isOptional: false)
        ]
        entity.uniquenessConstraints = [["keyword"]]
        return entity
    }
    
    /*
     FavoriteRecord 엔티티를 생성합니다.

     생성 시각과 식별자, 타입을 저장하며,
     FavoriteRecordMO를 represented class로 사용합니다.
     id와 type 조합을 uniqueness constraint로 사용합니다.
     */
    static func makeFavoriteRecordEntity() -> NSEntityDescription {
        let entity = makeEntity(
            named: "FavoriteRecord",
            managedObjectClassName: NSStringFromClass(FavoriteRecordMO.self)
        )
        entity.properties = [
            makeDateAttribute(named: "createdAt", isOptional: false),
            makeStringAttribute(named: "id", isOptional: false),
            makeStringAttribute(named: "type", isOptional: false)
        ]
        entity.uniquenessConstraints = [["id", "type"]]
        return entity
    }

    /*
     CacheEntry 엔티티를 생성합니다.

     namespace와 key 조합을 기준으로 캐시 항목을 식별하고,
     payload와 만료 시각 같은 캐시 메타데이터를 함께 저장합니다.
     */
    static func makeCacheEntryEntity() -> NSEntityDescription {
        let entity = makeEntity(named: "CacheEntry")
        entity.properties = [
            makeDateAttribute(named: "createdAt", isOptional: false),
            makeStringAttribute(named: "eTag", isOptional: true),
            makeDateAttribute(named: "expiresAt", isOptional: true),
            makeStringAttribute(named: "key", isOptional: false),
            makeStringAttribute(named: "namespace", isOptional: false),
            makeBinaryAttribute(named: "payload", isOptional: false),
            makeInt64Attribute(named: "version", isOptional: false, defaultValue: 0)
        ]
        entity.uniquenessConstraints = [["namespace", "key"]]
        return entity
    }

    /*
     SessionSnapshot 엔티티를 생성합니다.

     환경별 로그인 상태와 마지막 갱신 시각을 저장하며,
     environment를 uniqueness constraint로 사용합니다.
     */
    static func makeSessionSnapshotEntity() -> NSEntityDescription {
        let entity = makeEntity(named: "SessionSnapshot")
        entity.properties = [
            makeStringAttribute(named: "environment", isOptional: false),
            makeBoolAttribute(named: "isLoggedIn", isOptional: false, defaultValue: false),
            makeDateAttribute(named: "lastRefreshedAt", isOptional: true),
            makeStringAttribute(named: "userID", isOptional: true)
        ]
        entity.uniquenessConstraints = [["environment"]]
        return entity
    }

    /*
     SyncStateRecord 엔티티를 생성합니다.

     namespace별 동기화 커서와 dirty 상태를 저장하며,
     namespace를 uniqueness constraint로 사용합니다.
     */
    static func makeSyncStateRecordEntity() -> NSEntityDescription {
        let entity = makeEntity(named: "SyncStateRecord")
        entity.properties = [
            makeStringAttribute(named: "cursor", isOptional: true),
            makeBoolAttribute(named: "isDirty", isOptional: false, defaultValue: false),
            makeDateAttribute(named: "lastSyncedAt", isOptional: true),
            makeStringAttribute(named: "namespace", isOptional: false)
        ]
        entity.uniquenessConstraints = [["namespace"]]
        return entity
    }
}

private extension ProgrammaticPersistenceModel {
    /*
     기본 NSManagedObject 엔티티를 생성합니다.

     엔티티 이름과 represented class 이름을 함께 지정할 수 있으며,
     별도 ManagedObject 서브클래스가 없는 엔티티는 기본 NSManagedObject를 사용합니다.

     Parameters:
     - name: 생성할 엔티티 이름
     - managedObjectClassName: 엔티티가 사용할 ManagedObject 클래스 이름

     Returns:
     - 기본 설정이 완료된 NSEntityDescription
     */
    static func makeEntity(
        named name: String,
        managedObjectClassName: String = NSStringFromClass(NSManagedObject.self)
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = managedObjectClassName
        return entity
    }

    /* 문자열 속성을 생성합니다. */
    static func makeStringAttribute(
        named name: String,
        isOptional: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .stringAttributeType
        attribute.isOptional = isOptional
        return attribute
    }

    /* 날짜 속성을 생성합니다. */
    static func makeDateAttribute(
        named name: String,
        isOptional: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .dateAttributeType
        attribute.isOptional = isOptional
        return attribute
    }

    /* Bool 속성을 생성합니다. */
    static func makeBoolAttribute(
        named name: String,
        isOptional: Bool,
        defaultValue: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .booleanAttributeType
        attribute.isOptional = isOptional
        attribute.defaultValue = defaultValue
        return attribute
    }

    /* Int64 속성을 생성합니다. */
    static func makeInt64Attribute(
        named name: String,
        isOptional: Bool,
        defaultValue: Int64
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .integer64AttributeType
        attribute.isOptional = isOptional
        attribute.defaultValue = defaultValue
        return attribute
    }

    /* Binary Data 속성을 생성합니다. */
    static func makeBinaryAttribute(
        named name: String,
        isOptional: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .binaryDataAttributeType
        attribute.isOptional = isOptional
        return attribute
    }
}
