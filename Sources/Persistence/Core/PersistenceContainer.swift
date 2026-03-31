//
//  PersistenceContainer.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation

/*
 Persistence 모듈의 조립 진입점입니다.

 앱 또는 상위 모듈은 이 타입을 통해 Persistence 기능에 접근합니다.
 컨테이너는 저장소 초기화에 필요한 설정과 Core Data stack를 보관하고,
 이후 검색 기록, 캐시, 즐겨찾기 같은 저장 기능 객체를 구성하는 기반 역할을 담당합니다.

 모델 공급 방식은 설정에 포함되므로,
 컨테이너는 .xcdatamodeld 기반 구성과 programmatic model 기반 구성을
 동일한 초기화 흐름으로 다룰 수 있습니다.
 */
public final class PersistenceContainer {
    private let coreDataStack: CoreDataStackProtocol

    /*
     컨테이너 생성에 사용된 설정값입니다.

     어떤 모델 공급 방식과 저장소 종류로 초기화되었는지 확인해야 할 때 참조할 수 있습니다.
     */
    public let configuration: PersistenceConfiguration

    private init(
        configuration: PersistenceConfiguration,
        coreDataStack: CoreDataStackProtocol
    ) {
        self.configuration = configuration
        self.coreDataStack = coreDataStack
    }

    /*
     지정한 설정으로 PersistenceContainer를 생성합니다.

     이 메서드는 외부에서 Persistence 모듈을 초기화할 때 사용하는 기본 진입점입니다.
     내부적으로 CoreDataStack 생성과 persistent store 로딩을 완료한 뒤,
     준비된 컨테이너를 반환합니다.

     Parameters:
     - configuration: 모델 공급 방식, 저장소 종류, merge policy 등을 포함한 설정값

     Returns:
     - 사용할 준비가 완료된 PersistenceContainer

     Throws:
     - 설정값 검증 실패
     - Core Data 모델 로딩 실패
     - persistent store 로딩 실패
     */
    public static func make(
        configuration: PersistenceConfiguration
    ) async throws -> PersistenceContainer {
        let coreDataStack = try await CoreDataStack.make(configuration: configuration)

        return PersistenceContainer(
            configuration: configuration,
            coreDataStack: coreDataStack
        )
    }

    /*
     기본 번들 모델과 SQLite 저장소를 사용하는 컨테이너를 생성합니다.

     .xcdatamodeld를 기본 운영 모델로 사용할 때 간단히 호출할 수 있는 편의 메서드입니다.

     Returns:
     - 기본 bundle 모델 + live 저장소 설정으로 초기화된 PersistenceContainer

     Throws:
     - 기본 설정 생성 실패
     - Core Data 초기화 실패
     */
    public static func makeDefault() async throws -> PersistenceContainer {
        try await make(configuration: try .live())
    }

    /*
     코드 기반 기본 모델과 in-memory 저장소를 사용하는 컨테이너를 생성합니다.

     리소스 번들 없이 모델 구성을 빠르게 확인하거나,
     샘플 실행과 테스트 보조 용도로 사용할 수 있는 편의 메서드입니다.

     Returns:
     - 기본 programmatic 모델 + in-memory 저장소 설정으로 초기화된 PersistenceContainer

     Throws:
     - 코드 기반 모델 검증 실패
     - Core Data 초기화 실패
     */
    public static func makeDefaultProgrammaticInMemory() async throws -> PersistenceContainer {
        try await make(
            configuration: .inMemory(
                modelSource: ProgrammaticPersistenceModel.defaultSource()
            )
        )
    }
    
    /*
     검색 기록 저장소 구현체를 생성합니다.

     상위 계층은 구체적인 Core Data 구현체 대신
     SearchHistoryStoreProtocol 계약을 통해 검색 기록 기능에 접근합니다.
     이 메서드는 현재 컨테이너가 보관 중인 Core Data stack을 사용해
     검색 기록 저장소를 조립한 뒤 반환합니다.

     Returns:
     - 검색 기록 조회, 저장, 삭제 기능을 제공하는 SearchHistoryStoreProtocol 구현체
     */
    public func makeSearchHistoryStore() -> SearchHistoryStoreProtocol {
        CoreDataSearchHistoryStore(coreDataStack: coreDataStack)
    }
    
    /*
     즐겨찾기 저장소 구현체를 생성합니다.

     상위 계층은 구체적인 Core Data 구현체 대신
     FavoriteStoreProtocol 계약을 통해 즐겨찾기 기능에 접근합니다.
     이 메서드는 현재 컨테이너가 보관 중인 Core Data stack을 사용해
     즐겨찾기 저장소를 조립한 뒤 반환합니다.

     Returns:
     - 즐겨찾기 조회, 저장, 삭제 기능을 제공하는 FavoriteStoreProtocol 구현체
     */
    public func makeFavoriteStore() -> FavoriteStoreProtocol {
        CoreDataFavoriteStore(coreDataStack: coreDataStack)
    }
    
    /*
     세션 스냅샷 저장소 구현체를 생성합니다.

     상위 계층은 구체적인 Core Data 구현체 대신
     SessionSnapshotStoreProtocol 계약을 통해 세션 스냅샷 기능에 접근합니다.
     이 메서드는 현재 컨테이너가 보관 중인 Core Data stack을 사용해
     세션 스냅샷 저장소를 조립한 뒤 반환합니다.

     Returns:
     - 세션 스냅샷 조회, 저장, 삭제 기능을 제공하는 SessionSnapshotStoreProtocol 구현체
     */
    public func makeSessionSnapshotStore() -> SessionSnapshotStoreProtocol {
        CoreDataSessionSnapshotStore(coreDataStack: coreDataStack)
    }
}
