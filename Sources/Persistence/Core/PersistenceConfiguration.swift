//
//  PersistenceConfiguration.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
import CoreData

/*
 Persistence 저장소 구성을 정의하는 설정 타입입니다.

 Core Data stack를 생성하려면 모델 공급 방식, 저장소 종류,
 읽기 전용 여부, context 병합 정책 같은 초기화 정보가 필요합니다.
 이 타입은 그러한 설정을 한 곳에 모아 stack 생성 시점에 전달하기 위한 값 객체입니다.

 지원하는 모델 공급 방식
 - bundle: .xcdatamodeld 또는 컴파일된 .mom/.momd 리소스를 번들에서 로드
 - programmatic: 코드로 구성한 NSManagedObjectModel을 직접 생성

 주요 사용 예
 - 실제 앱에서 디스크 기반 SQLite 저장소 생성
 - 테스트에서 메모리 기반 저장소 생성
 - 리소스 번들 없이 코드 기반 모델로 동작 확인
 - merge policy나 자동 병합 여부를 환경별로 분리
 */
public struct PersistenceConfiguration {
    /*
     Core Data 모델을 어떤 방식으로 준비할지 나타내는 타입입니다.

     bundle
     - .xcdatamodeld, .momd, .mom 같은 번들 리소스를 사용합니다.
     - Xcode 모델 편집기와 버전 관리 기능을 그대로 활용할 수 있습니다.

     programmatic
     - 코드를 통해 NSManagedObjectModel을 직접 생성합니다.
     - 리소스 번들 없이 테스트하거나, 모델 구조를 코드로 제어할 때 적합합니다.
     */
    public enum ManagedObjectModelSource {
        case bundle(modelName: String, bundle: Bundle)
        case programmatic(
            modelName: String,
            makeManagedObjectModel: () throws -> NSManagedObjectModel
        )
    }

    /*
     사용할 저장소 종류를 나타냅니다.

     sqlite(url:)
     - 디스크 파일 기반 저장소입니다.
     - 앱 재실행 이후에도 데이터가 유지됩니다.
     - 일반 서비스 환경에서 기본 저장소로 사용합니다.

     inMemory
     - 메모리 기반 저장소입니다.
     - 프로세스가 종료되면 데이터가 사라집니다.
     - 테스트, 샘플 데이터 주입, Preview 환경에 적합합니다.
     */
    public enum StoreKind: Equatable {
        case sqlite(url: URL)
        case inMemory
    }

    /*
     Core Data merge policy를 표현하는 열거형입니다.

     설정 객체는 NSMergePolicy 구현 세부 사항을 직접 노출하지 않고,
     의미 중심의 enum으로 정책을 전달합니다.
     실제 NSMergePolicy 변환은 아래 extension에서 수행합니다.
     */
    public enum MergePolicyKind {
        case objectTrump
        case storeTrump
        case overwrite
        case rollback
        case error
    }

    /* Core Data 모델 공급 방식 */
    public let modelSource: ManagedObjectModelSource

    /* 실제 저장 방식(SQLite 또는 InMemory) */
    public let storeKind: StoreKind

    /* 저장소를 읽기 전용으로 열지 여부 */
    public let isReadOnly: Bool

    /* persistent store를 비동기로 추가할지 여부 */
    public let shouldAddStoreAsynchronously: Bool

    /*
     viewContext가 background context 저장 결과를 자동 병합할지 여부입니다.

     background context에서 저장된 변경 사항을 화면 계층이 자연스럽게 반영하려면
     일반적으로 true 구성이 유리합니다.
     */
    public let viewContextAutomaticallyMergesChangesFromParent: Bool

    /* main queue에서 동작하는 viewContext의 merge policy */
    public let viewContextMergePolicy: MergePolicyKind

    /* background read/write context의 merge policy */
    public let backgroundContextMergePolicy: MergePolicyKind

    /*
     설정에 포함된 모델 이름입니다.

     bundle 기반 모델과 programmatic 모델 모두 공통적으로
     컨테이너 이름과 검증 메시지에 사용할 수 있도록 계산 프로퍼티로 제공합니다.
     */
    public var modelName: String {
        switch modelSource {
        case let .bundle(modelName, _):
            return modelName
        case let .programmatic(modelName, _):
            return modelName
        }
    }

    /*
     bundle 기반 모델일 때 참조한 번들입니다.

     programmatic 모델은 번들 리소스를 사용하지 않으므로 nil을 반환합니다.
     */
    public var modelBundle: Bundle? {
        switch modelSource {
        case let .bundle(_, bundle):
            return bundle
        case .programmatic:
            return nil
        }
    }

    public init(
        modelSource: ManagedObjectModelSource,
        storeKind: StoreKind,
        isReadOnly: Bool = false,
        shouldAddStoreAsynchronously: Bool = false,
        viewContextAutomaticallyMergesChangesFromParent: Bool = true,
        viewContextMergePolicy: MergePolicyKind = .objectTrump,
        backgroundContextMergePolicy: MergePolicyKind = .objectTrump
    ) {
        self.modelSource = modelSource
        self.storeKind = storeKind
        self.isReadOnly = isReadOnly
        self.shouldAddStoreAsynchronously = shouldAddStoreAsynchronously
        self.viewContextAutomaticallyMergesChangesFromParent = viewContextAutomaticallyMergesChangesFromParent
        self.viewContextMergePolicy = viewContextMergePolicy
        self.backgroundContextMergePolicy = backgroundContextMergePolicy
    }

    /*
     bundle 리소스를 사용하는 기존 초기화 방식입니다.

     .xcdatamodeld 기반 구성을 유지하는 호출부가 변경 없이 동작하도록,
     전달받은 모델 이름과 번들을 bundle 기반 modelSource로 감싸서 저장합니다.
     */
    public init(
        modelName: String,
        modelBundle: Bundle,
        storeKind: StoreKind,
        isReadOnly: Bool = false,
        shouldAddStoreAsynchronously: Bool = false,
        viewContextAutomaticallyMergesChangesFromParent: Bool = true,
        viewContextMergePolicy: MergePolicyKind = .objectTrump,
        backgroundContextMergePolicy: MergePolicyKind = .objectTrump
    ) {
        self.init(
            modelSource: .bundle(modelName: modelName, bundle: modelBundle),
            storeKind: storeKind,
            isReadOnly: isReadOnly,
            shouldAddStoreAsynchronously: shouldAddStoreAsynchronously,
            viewContextAutomaticallyMergesChangesFromParent: viewContextAutomaticallyMergesChangesFromParent,
            viewContextMergePolicy: viewContextMergePolicy,
            backgroundContextMergePolicy: backgroundContextMergePolicy
        )
    }

    /*
     실제 앱에서 사용할 SQLite 기반 설정을 생성합니다.

     호출하는 쪽이 bundle 기반 모델 또는 programmatic 모델을 직접 선택해서
     전달할 수 있도록 modelSource를 명시적으로 받습니다.

     동작 방식
     - baseDirectoryURL이 있으면 해당 디렉터리를 기준 경로로 사용합니다.
     - baseDirectoryURL이 없으면 Application Support 디렉터리를 조회합니다.
     - 지정한 디렉터리명이 없으면 생성합니다.
     - 해당 위치에 SQLite 파일 URL을 구성합니다.
     - 생성된 URL을 사용해 sqlite 저장소 설정을 반환합니다.

     Parameters:
     - modelSource: 사용할 Core Data 모델 공급 방식
     - directoryName: 저장소 파일을 보관할 하위 디렉터리 이름
     - fileName: SQLite 파일 이름
     - baseDirectoryURL: 저장소 디렉터리를 만들 기준 경로

     Returns:
     - 디스크 기반 저장소를 위한 PersistenceConfiguration

     Throws:
     - 설정값이 비어 있거나 올바르지 않은 경우
     - 디렉터리 조회 또는 생성에 실패한 경우
     */
    public static func live(
        modelSource: ManagedObjectModelSource,
        directoryName: String = "Persistence",
        fileName: String = "Persistence.sqlite",
        baseDirectoryURL: URL? = nil
    ) throws -> PersistenceConfiguration {
        try validateNonEmpty(modelSource.modelName, name: "modelName")
        try validateNonEmpty(directoryName, name: "directoryName")
        try validateNonEmpty(fileName, name: "fileName")

        let fileManager = FileManager.default

        let rootDirectoryURL: URL
        if let baseDirectoryURL {
            rootDirectoryURL = baseDirectoryURL
        } else {
            rootDirectoryURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        let persistenceDirectoryURL = rootDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)

        try fileManager.createDirectory(
            at: persistenceDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let storeURL = persistenceDirectoryURL.appendingPathComponent(fileName)

        return PersistenceConfiguration(
            modelSource: modelSource,
            storeKind: .sqlite(url: storeURL)
        )
    }

    /*
     패키지에 포함된 기본 bundle 모델을 사용해 SQLite 기반 설정을 생성합니다.

     public default argument에서 Bundle.module을 직접 사용할 수 없으므로,
     기본 모델을 사용하는 경로는 별도 오버로드로 제공합니다.
     */
    public static func live(
        directoryName: String = "Persistence",
        fileName: String = "Persistence.sqlite",
        baseDirectoryURL: URL? = nil
    ) throws -> PersistenceConfiguration {
        try live(
            modelSource: .bundle(
                modelName: "PersistenceModel",
                bundle: .module
            ),
            directoryName: directoryName,
            fileName: fileName,
            baseDirectoryURL: baseDirectoryURL
        )
    }

    /*
     bundle 리소스를 명시적으로 지정해 SQLite 기반 설정을 생성하는 방식입니다.

     앱 타깃, 테스트 번들, 별도 리소스 번들처럼 모델 위치를 직접 지정해야 할 때 사용합니다.
     */
    public static func live(
        modelName: String,
        modelBundle: Bundle,
        directoryName: String = "Persistence",
        fileName: String = "Persistence.sqlite",
        baseDirectoryURL: URL? = nil
    ) throws -> PersistenceConfiguration {
        try live(
            modelSource: .bundle(modelName: modelName, bundle: modelBundle),
            directoryName: directoryName,
            fileName: fileName,
            baseDirectoryURL: baseDirectoryURL
        )
    }

    /*
     테스트나 미리보기 환경에 적합한 in-memory 설정을 생성합니다.

     실제 파일을 만들지 않고 프로세스 메모리 안에서만 동작하므로,
     테스트 실행 속도가 빠르고 데이터 격리가 쉬운 것이 장점입니다.

     Parameters:
     - modelSource: 사용할 Core Data 모델 공급 방식

     Returns:
     - 메모리 기반 저장소를 위한 PersistenceConfiguration
     */
    public static func inMemory(
        modelSource: ManagedObjectModelSource
    ) -> PersistenceConfiguration {
        PersistenceConfiguration(
            modelSource: modelSource,
            storeKind: .inMemory
        )
    }

    /*
     패키지에 포함된 기본 bundle 모델을 사용해 in-memory 설정을 생성합니다.

     public default argument에서 Bundle.module을 직접 사용할 수 없으므로,
     기본 모델을 사용하는 경로는 별도 오버로드로 제공합니다.
     */
    public static func inMemory() -> PersistenceConfiguration {
        PersistenceConfiguration(
            modelSource: .bundle(
                modelName: "PersistenceModel",
                bundle: .module
            ),
            storeKind: .inMemory
        )
    }

    /*
     bundle 리소스를 명시적으로 지정해 in-memory 설정을 생성하는 방식입니다.

     테스트 번들 또는 별도 리소스 번들에 포함된 모델을 사용해야 할 때 적합합니다.
     */
    public static func inMemory(
        modelName: String,
        modelBundle: Bundle
    ) -> PersistenceConfiguration {
        PersistenceConfiguration(
            modelSource: .bundle(modelName: modelName, bundle: modelBundle),
            storeKind: .inMemory
        )
    }
}

extension PersistenceConfiguration.ManagedObjectModelSource {
    /*
     설정에 포함된 모델 이름입니다.

     모델 공급 방식에 상관없이 공통 검증과 container 이름 구성에 사용합니다.
     */
    var modelName: String {
        switch self {
        case let .bundle(modelName, _):
            return modelName
        case let .programmatic(modelName, _):
            return modelName
        }
    }
}

extension PersistenceConfiguration {
    /*
     PersistenceConfiguration에 포함된 필수 값이 유효한지 확인합니다.

     설정 객체는 생성 자체는 자유롭게 할 수 있지만,
     실제 stack를 구성하는 시점에는 필수 문자열 값이 비어 있지 않아야 합니다.
     이 검증은 stack 초기화 전에 잘못된 구성을 빠르게 식별하기 위해 사용합니다.

     Throws:
     - 필수 값이 비어 있으면 PersistenceError.invalidConfiguration
     */
    func validate() throws {
        try Self.validateNonEmpty(modelSource.modelName, name: "modelName")
    }

    /*
     NSPersistentContainer에 주입할 NSPersistentStoreDescription을 생성합니다.

     storeKind에 따라 SQLite 저장소 또는 InMemory 저장소를 구성하며,
     읽기 전용 여부와 비동기 추가 여부를 함께 반영합니다.

     주의할 점
     - 이 값은 loadPersistentStores 호출 전에 container에 주입해야 합니다.
     - store 로딩 이후에 변경해도 이미 연결된 저장소 동작에는 반영되지 않습니다.
     */
    var persistentStoreDescription: NSPersistentStoreDescription {
        let description: NSPersistentStoreDescription

        switch storeKind {
        case let .sqlite(url):
            description = NSPersistentStoreDescription(url: url)
            description.type = NSSQLiteStoreType

        case .inMemory:
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
        }

        description.shouldAddStoreAsynchronously = shouldAddStoreAsynchronously
        description.isReadOnly = isReadOnly

        return description
    }
}

extension PersistenceConfiguration.MergePolicyKind {
    /*
     설정용 enum 값을 Core Data의 NSMergePolicy로 변환합니다.

     이 변환을 별도 extension에 두면,
     설정 타입은 의미 중심의 enum만 노출하고 Core Data 의존성은 내부로 제한할 수 있습니다.

     Returns:
     - 해당 정책에 대응하는 NSMergePolicy
     */
    var nsMergePolicy: NSMergePolicy {
        switch self {
        case .objectTrump:
            return NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        case .storeTrump:
            return NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        case .overwrite:
            return NSMergePolicy(merge: .overwriteMergePolicyType)
        case .rollback:
            return NSMergePolicy(merge: .rollbackMergePolicyType)
        case .error:
            return NSMergePolicy(merge: .errorMergePolicyType)
        }
    }
}

private extension PersistenceConfiguration {
    /*
     문자열 기반 필수 설정값이 비어 있지 않은지 확인합니다.

     공백만 포함된 문자열도 유효하지 않은 값으로 처리하여,
     저장소 생성 전에 명확한 설정 오류를 반환합니다.

     Parameters:
     - value: 검증할 문자열 값
     - name: 오류 메시지에 포함할 설정 이름

     Throws:
     - 값이 비어 있거나 공백만 포함된 경우 PersistenceError.invalidConfiguration
     */
    static func validateNonEmpty(_ value: String, name: String) throws {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.isEmpty {
            throw PersistenceError.invalidConfiguration("\(name)은(는) 비어 있을 수 없습니다.")
        }
    }
}
