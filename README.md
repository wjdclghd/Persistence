# Persistence Module

Clean Architecture + MVVM 환경에서 App 타겟이 SPM 모듈로 의존하는 형태를 전제로 만든 Persistence 모듈입니다.
이 모듈은 **로컬 저장소(Local Persistence)** 역할에 집중하며, Core Data 기반 저장 구조를 외부에 직접 노출하지 않고 **공개 모델 + 저장소 계약 + 내부 구현체**로 역할을 분리합니다.

모듈 내부는 특정 Feature 로직을 직접 가지지 않고,
상위 계층이 `PersistenceContainer`를 통해 필요한 저장소를 조립해서 사용하도록 설계되어 있습니다.

**요약**
- 저장소 초기화: `PersistenceConfiguration` + `CoreDataStack`
- 조립 진입점: `PersistenceContainer`
- migration 정책: `PersistenceMigrationPlan`
- 모델 공급 방식: bundle model / programmatic model
- 공개 계약: `API/Models`, `API/Stores`
- 내부 구현: `ManagedObjects`, `Mappers`, `StoreImplementations`
- 현재 구현 저장소: `SearchHistory`, `Favorite`, `SessionSnapshot`, `Cache`, `SyncState`

---

**모듈 구조**
- API
  - Models
  - Stores
- Core
- ManagedObjects
- Mappers
- StoreImplementations
- Resources
- Tests

예시 구조:
```text
Persistence/
├─ Package.swift
├─ Sources/
│  └─ Persistence/
│     ├─ API/
│     │  ├─ Models/
│     │  │  ├─ PersistenceError.swift
│     │  │  ├─ SearchHistoryRecord.swift
│     │  │  ├─ FavoriteRecord.swift
│     │  │  ├─ SessionSnapshot.swift
│     │  │  ├─ CacheEntry.swift
│     │  │  └─ SyncStateRecord.swift
│     │  └─ Stores/
│     │     ├─ SearchHistoryStoreProtocol.swift
│     │     ├─ FavoriteStoreProtocol.swift
│     │     ├─ SessionSnapshotStoreProtocol.swift
│     │     ├─ CacheStoreProtocol.swift
│     │     └─ SyncStateStoreProtocol.swift
│     ├─ Core/
│     │  ├─ CoreDataStack.swift
│     │  ├─ CoreDataStackProtocol.swift
│     │  ├─ ContextExecutor.swift
│     │  ├─ PersistenceConfiguration.swift
│     │  ├─ PersistenceContainer.swift
│     │  ├─ PersistenceMigrationPlan.swift
│     │  └─ ProgrammaticPersistenceModel.swift
│     ├─ ManagedObjects/
│     │  ├─ SearchHistoryRecordMO.swift
│     │  ├─ FavoriteRecordMO.swift
│     │  ├─ SessionSnapshotMO.swift
│     │  ├─ CacheEntryMO.swift
│     │  └─ SyncStateRecordMO.swift
│     ├─ Mappers/
│     │  ├─ SearchHistoryRecordMapper.swift
│     │  ├─ FavoriteRecordMapper.swift
│     │  ├─ SessionSnapshotMapper.swift
│     │  ├─ CacheEntryMapper.swift
│     │  └─ SyncStateRecordMapper.swift
│     ├─ StoreImplementations/
│     │  ├─ SearchHistory/
│     │  │  └─ CoreDataSearchHistoryStore.swift
│     │  ├─ Favorite/
│     │  │  └─ CoreDataFavoriteStore.swift
│     │  ├─ SessionSnapshot/
│     │  │  └─ CoreDataSessionSnapshotStore.swift
│     │  ├─ Cache/
│     │  │  └─ CoreDataCacheStore.swift
│     │  └─ SyncState/
│     │     └─ CoreDataSyncStateStore.swift
│     └─ Resources/
│        └─ PersistenceModel.xcdatamodeld
└─ Tests/
   └─ PersistenceTests/
      ├─ InMemoryCoreDataStack.swift
      ├─ CoreDataStackTests.swift
      ├─ PersistenceConfigurationTests.swift
      ├─ PersistenceMigrationPlanTests.swift
      ├─ CoreDataMigrationTests.swift
      ├─ SearchHistoryStoreTests.swift
      ├─ FavoriteStoreTests.swift
      ├─ SessionSnapshotStoreTests.swift
      ├─ CacheStoreTests.swift
      └─ SyncStateStoreTests.swift
```

---

**빠른 시작**
```swift
import Persistence

let container = try await PersistenceContainer.makeDefault()
let searchHistoryStore = container.makeSearchHistoryStore()

try await searchHistoryStore.save(
    SearchHistoryRecord(
        keyword: "swiftui",
        lastSearchedAt: Date()
    )
)

let records = try await searchHistoryStore.fetchAll()
print(records)
```

테스트나 샘플 실행처럼 디스크 저장소가 필요 없는 환경에서는 in-memory 구성이 더 간단합니다.

```swift
import Persistence

let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
let favoriteStore = container.makeFavoriteStore()

try await favoriteStore.save(
    FavoriteRecord(
        id: "100",
        type: "movie",
        createdAt: Date()
    )
)

let favorites = try await favoriteStore.fetchAll()
print(favorites)
```

---

**핵심 설계 방향**
Persistence 모듈은 다음 원칙을 기준으로 구성합니다.

- **외부 공개 계약과 내부 구현 분리**
  - 상위 계층은 `API/Models`, `API/Stores`에만 의존합니다.
  - `NSManagedObject`, `NSFetchRequest`, `NSPersistentContainer` 같은 Core Data 세부 구현은 내부에 감춥니다.

- **조립 지점 통일**
  - 앱 또는 상위 모듈은 `PersistenceContainer`를 통해 저장소를 생성합니다.
  - 구체 구현체를 직접 생성하기보다, 컨테이너 조립을 통해 일관된 초기화 흐름을 유지합니다.

- **저장소별 책임 분리**
  - SearchHistory, Favorite, SessionSnapshot, Cache, SyncState는 각각 독립된 Store 계약과 구현체를 가집니다.
  - 저장 정책, 정렬 규칙, 공백 정규화 규칙도 저장소별로 관리합니다.

- **테스트 친화적인 구조**
  - bundle model뿐 아니라 programmatic model도 지원합니다.
  - in-memory store를 쉽게 구성할 수 있어 단위 테스트와 샘플 실행에 유리합니다.

---

**PersistenceContainer**
`PersistenceContainer`는 Persistence 모듈의 **조립 진입점(composition entry point)** 입니다.

제공 기능:
- `make(configuration:)`
- `makeDefault()`
- `makeDefaultProgrammaticInMemory()`
- `makeSearchHistoryStore()`
- `makeFavoriteStore()`
- `makeSessionSnapshotStore()`
- `makeCacheStore()`
- `makeSyncStateStore()`

예시:
```swift
let configuration = try PersistenceConfiguration.live()
let container = try await PersistenceContainer.make(configuration: configuration)

let cacheStore = container.makeCacheStore()
let sessionStore = container.makeSessionSnapshotStore()
let syncStateStore = container.makeSyncStateStore()
```

상위 계층은 `CoreDataSearchHistoryStore` 같은 구체 타입보다
`SearchHistoryStoreProtocol`, `CacheStoreProtocol` 같은 계약을 기준으로 사용하는 것이 권장됩니다.

---

**PersistenceConfiguration**
`PersistenceConfiguration`은 저장소 초기화에 필요한 값을 한 곳에 모아 관리하는 설정 객체입니다.

주요 설정 항목:
- `modelSource`
- `storeKind`
- `isReadOnly`
- `shouldAddStoreAsynchronously`
- `migrationPlan`
- `viewContextAutomaticallyMergesChangesFromParent`
- `viewContextMergePolicy`
- `backgroundContextMergePolicy`

생성 방법:
- `live(...)`: 디스크 기반 SQLite 저장소
- `inMemory(...)`: 메모리 기반 저장소

### live 예시
```swift
let configuration = try PersistenceConfiguration.live(
    directoryName: "Persistence",
    fileName: "Persistence.sqlite"
)
```

### in-memory 예시
```swift
let configuration = PersistenceConfiguration.inMemory(
    modelSource: ProgrammaticPersistenceModel.defaultSource()
)
```

---

**모델 공급 방식**
Persistence는 Core Data 모델을 두 가지 방식으로 준비할 수 있습니다.

### 1. bundle model
`.xcdatamodeld`, `.mom`, `.momd` 같은 번들 리소스를 사용하는 방식입니다.

적합한 경우:
- 실제 앱 운영 환경
- Xcode 모델 편집기 사용
- 모델 버전 관리와 migration 관리

### 2. programmatic model
코드로 `NSManagedObjectModel`을 직접 생성하는 방식입니다.

적합한 경우:
- 단위 테스트
- 리소스 번들 없이 빠른 실행 확인
- 모델 구조를 코드로 직접 제어하고 싶은 경우

---

**Migration**
`PersistenceMigrationPlan`은 store 로딩 시 적용할 migration 정책을 정의합니다.

기본 제공 정책:
- `PersistenceMigrationPlan.lightweight`
- `PersistenceMigrationPlan.disabled`

### lightweight migration
- automatic migration 사용
- inferred mapping model 사용
- 속성 추가, optional 변경 등 Core Data가 자동 추론 가능한 변경에 적합

### disabled
- migration 미수행
- 현재 모델과 기존 store가 호환되지 않으면 store 로딩 실패

예시:
```swift
let configuration = try PersistenceConfiguration.live(
    migrationPlan: .lightweight
)
```

중요한 점:
- migration 정책을 **결정하는 곳은 `PersistenceConfiguration`** 입니다.
- `CoreDataStack`은 이미 준비된 store description을 사용해 store를 로드합니다.
- 즉 migration은 stack 내부 분기보다 **configuration 기반 정책 주입**으로 관리합니다.

---

**CoreDataStack**
`CoreDataStack`은 Persistence 모듈의 Core Data 기반 foundation입니다.

담당 역할:
- `NSManagedObjectModel` 준비
- `NSPersistentContainer` 생성
- persistent store description 주입
- persistent store 로딩
- `viewContext` 정책 구성
- background context 생성
- 공통 읽기/쓰기 실행 경로 제공

외부에 직접 노출되는 저장소 구현 상세를 최소화하기 위해,
상위 계층은 `CoreDataStack`을 직접 다루기보다 `PersistenceContainer`와 Store 계약을 사용하는 것이 기본입니다.

---

**공개 모델과 저장소 계약**
Persistence 모듈이 외부에 노출하는 모델은 다음과 같습니다.

- `SearchHistoryRecord`
- `FavoriteRecord`
- `SessionSnapshot`
- `CacheEntry`
- `SyncStateRecord`
- `PersistenceError`

저장소 계약은 다음과 같습니다.

- `SearchHistoryStoreProtocol`
- `FavoriteStoreProtocol`
- `SessionSnapshotStoreProtocol`
- `CacheStoreProtocol`
- `SyncStateStoreProtocol`

이 구조의 목적은 다음과 같습니다.
- 상위 계층이 Core Data 내부 타입을 몰라도 된다.
- 로컬 저장소 구현을 바꾸더라도 공개 계약은 안정적으로 유지할 수 있다.
- 테스트 더블이나 대체 구현체를 만들기 쉽다.

---

**현재 제공하는 저장소**

### SearchHistory
최근 검색 기록을 저장하는 저장소입니다.

특징:
- `keyword` 기준 upsert
- 전체 조회 시 `lastSearchedAt desc`
- 키워드 필터 조회 지원
- 공백 keyword 저장 차단
- 개별 삭제 / 전체 삭제 지원

예시:
```swift
let store = container.makeSearchHistoryStore()

try await store.save(
    SearchHistoryRecord(
        keyword: "combine",
        lastSearchedAt: Date()
    )
)

let recentKeywords = try await store.fetchAll()
```

### Favorite
즐겨찾기 항목을 저장하는 저장소입니다.

특징:
- `id + type` 조합 기준 upsert
- 전체 조회 시 `createdAt desc`
- 타입별 조회 지원
- 단건 조회 지원
- 개별 삭제 / 전체 삭제 지원

예시:
```swift
let store = container.makeFavoriteStore()

try await store.save(
    FavoriteRecord(
        id: "200",
        type: "movie",
        createdAt: Date()
    )
)

let movieFavorites = try await store.fetchRecords(ofType: "movie")
```

### SessionSnapshot
환경별 세션 상태를 저장하는 저장소입니다.

특징:
- `environment` 기준 upsert
- 공백 `userID`는 `nil`로 정규화
- 특정 환경의 세션 스냅샷 조회 지원
- 개별 삭제 / 전체 삭제 지원

예시:
```swift
let store = container.makeSessionSnapshotStore()

try await store.save(
    SessionSnapshot(
        environment: "prod",
        isLoggedIn: true,
        lastRefreshedAt: Date(),
        userID: "user-1"
    )
)

let prodSession = try await store.fetchSnapshot(for: "prod")
```

### Cache
namespace 기반 캐시 항목을 저장하는 저장소입니다.

특징:
- `namespace + key` 조합 기준 upsert
- 단건 조회 / namespace별 목록 조회 지원
- `eTag` 공백은 `nil`로 정규화
- namespace 단위 삭제 / 전체 삭제 지원

예시:
```swift
let store = container.makeCacheStore()

try await store.save(
    CacheEntry(
        namespace: "appConfig",
        key: "home",
        payload: Data("cached".utf8),
        eTag: "etag-1",
        expiresAt: nil,
        createdAt: Date(),
        version: 1
    )
)

let entry = try await store.fetchEntry(namespace: "appConfig", key: "home")
```

### SyncState
동기화 진행 상태를 저장하는 저장소입니다.

특징:
- `namespace` 기준 upsert
- 공백 `cursor`는 `nil`로 정규화
- 특정 namespace의 동기화 상태 조회 지원
- 개별 삭제 / 전체 삭제 지원

예시:
```swift
let store = container.makeSyncStateStore()

try await store.save(
    SyncStateRecord(
        namespace: "home-feed",
        cursor: "cursor-10",
        isDirty: false,
        lastSyncedAt: Date()
    )
)

let syncState = try await store.fetchRecord(for: "home-feed")
```

---

**ManagedObjects / Mapper / StoreImplementations**
Persistence 내부 구현은 아래 계층으로 나뉩니다.

### ManagedObjects
Core Data 전용 `NSManagedObject` 타입입니다.

예:
- `SearchHistoryRecordMO`
- `FavoriteRecordMO`
- `SessionSnapshotMO`
- `CacheEntryMO`
- `SyncStateRecordMO`

### Mappers
공개 모델과 ManagedObject 사이를 변환합니다.

예:
- `SearchHistoryRecordMapper`
- `FavoriteRecordMapper`
- `SessionSnapshotMapper`
- `CacheEntryMapper`
- `SyncStateRecordMapper`

### StoreImplementations
실제 Core Data 저장/조회 로직을 구현합니다.

예:
- `CoreDataSearchHistoryStore`
- `CoreDataFavoriteStore`
- `CoreDataSessionSnapshotStore`
- `CoreDataCacheStore`
- `CoreDataSyncStateStore`

이 구조 덕분에 공개 API와 Core Data 구현 디테일을 분리할 수 있습니다.

---

**에러 모델**
Persistence 모듈은 `PersistenceError`를 통해 저장소 관련 오류를 일관되게 전달합니다.

주요 케이스:
- `invalidConfiguration`
- `modelNotFound`
- `persistentStoreLoadFailed`
- `readFailed`
- `writeFailed`

상위 계층은 Foundation 또는 Core Data의 원시 에러를 직접 해석하지 않고,
`PersistenceError`를 기준으로 실패를 분기하는 것이 좋습니다.

---

**테스트**
모듈은 in-memory Core Data 환경을 활용한 테스트를 포함합니다.

포함된 테스트 범위:
- `CoreDataStackTests`
- `PersistenceConfigurationTests`
- `PersistenceMigrationPlanTests`
- `CoreDataMigrationTests`
- `SearchHistoryStoreTests`
- `FavoriteStoreTests`
- `SessionSnapshotStoreTests`
- `CacheStoreTests`
- `SyncStateStoreTests`

테스트 전략:
- 공통 인프라 테스트와 저장소 기능 테스트를 분리합니다.
- programmatic model 기반 in-memory store를 사용해 빠르고 독립적인 검증을 수행합니다.
- 저장소별 정렬, upsert, 공백 입력 정규화, 삭제 동작, container 조립 결과를 검증합니다.

---

**권장 사용 전략**
- 상위 계층은 `PersistenceContainer`를 통해 저장소를 조립합니다.
- 화면/UseCase/Repository는 `API/Stores` 계약에 의존합니다.
- `ManagedObject`, `Mapper`, `CoreDataStack` 직접 의존은 Persistence 내부에 제한합니다.
- 운영 환경은 `live`, 테스트와 샘플 실행은 `inMemory`를 우선 사용합니다.
- migration 정책은 `PersistenceMigrationPlan`으로 환경별 분리 구성을 권장합니다.

---

**권장 확장 방식**

1. `API/Models`에 공개 모델 추가
2. `API/Stores`에 저장소 계약 추가
3. `ManagedObjects`에 Core Data 타입 추가
4. `Mappers`에 변환기 추가
5. `StoreImplementations`에 구현체 추가
6. `PersistenceContainer`에 조립 메서드 추가
7. `ProgrammaticPersistenceModel`과 `.xcdatamodeld`에 엔티티 반영
8. 저장소 전용 테스트 추가

---

Created by: JEONG, Chi-hong
Initial version: April 2026
