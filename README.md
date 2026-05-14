# Persistence Module

Clean Architecture + MVVM 환경에서 App 타겟이 SPM 모듈로 의존하는 형태를 전제로 만든 Persistence 모듈입니다.
이 모듈은 **로컬 저장소(Local Persistence)** 역할에 집중하며, Core Data 기반 저장 구조를 외부에 직접 노출하지 않고 **공개 Record + 저장소 계약 + 내부 구현체**로 역할을 분리합니다.

모듈 내부는 검색 기록, 즐겨찾기, 인증 세션, 세션 스냅샷, 캐시, 동기화 상태 6개 저장 도메인을 담당하며,
상위 계층은 `PersistenceContainer`를 통해 필요한 Store Protocol 구현체를 즉시 사용할 수 있습니다.

**요약**
- 저장소 초기화: `PersistenceConfiguration` + `CoreDataStack`
- 조립 진입점: `PersistenceContainer`
- 공개 Store 계약: `make*Store()` → `*StoreProtocol`
- migration 정책: `PersistenceMigrationPlan`
- 모델 공급 방식: bundle model / programmatic model
- 공개 계약: `Records`, `Stores`
- 내부 구현: `ManagedObjects`, `Mappers`, `CoreDataStores`
- 구현 도메인: `SearchHistory`, `Favorite`, `AuthSession`, `SessionSnapshot`, `Cache`, `SyncState`

---

**모듈 구조**
```text
Persistence/
├─ Package.swift
├─ Sources/
│  └─ Persistence/
│     ├─ Core/
│     │  ├─ PersistenceContainer.swift
│     │  ├─ PersistenceConfiguration.swift
│     │  ├─ PersistenceMigrationPlan.swift
│     │  ├─ ProgrammaticPersistenceModel.swift
│     │  ├─ CoreDataStack.swift
│     │  ├─ CoreDataStackProtocol.swift
│     │  └─ ContextExecutor.swift
│     ├─ Stores/
│     │  ├─ SearchHistoryStoreProtocol.swift
│     │  ├─ FavoriteStoreProtocol.swift
│     │  ├─ SessionSnapshotStoreProtocol.swift
│     │  ├─ AuthSessionStoreProtocol.swift
│     │  ├─ CacheStoreProtocol.swift
│     │  └─ SyncStateStoreProtocol.swift
│     ├─ CoreDataStores/
│     │  ├─ CoreDataSearchHistoryStore.swift
│     │  ├─ CoreDataFavoriteStore.swift
│     │  ├─ CoreDataSessionSnapshotStore.swift
│     │  ├─ CoreDataAuthSessionStore.swift
│     │  ├─ CoreDataCacheStore.swift
│     │  └─ CoreDataSyncStateStore.swift
│     ├─ Records/
│     │  ├─ SearchHistoryRecord.swift
│     │  ├─ FavoriteRecord.swift
│     │  ├─ SessionSnapshot.swift
│     │  ├─ AuthSessionRecord.swift
│     │  ├─ CacheEntry.swift
│     │  └─ SyncStateRecord.swift
│     ├─ ManagedObjects/
│     │  ├─ SearchHistoryRecordManagedObject.swift
│     │  ├─ FavoriteRecordManagedObject.swift
│     │  ├─ SessionSnapshotManagedObject.swift
│     │  ├─ AuthSessionRecordManagedObject.swift
│     │  ├─ CacheEntryManagedObject.swift
│     │  └─ SyncStateRecordManagedObject.swift
│     ├─ Mappers/
│     │  ├─ SearchHistoryRecordMapper.swift
│     │  ├─ FavoriteRecordMapper.swift
│     │  ├─ SessionSnapshotMapper.swift
│     │  ├─ AuthSessionRecordMapper.swift
│     │  ├─ CacheEntryMapper.swift
│     │  └─ SyncStateRecordMapper.swift
│     ├─ Errors/
│     │  └─ PersistenceError.swift
│     └─ Resources/
│        └─ PersistenceModel.xcdatamodeld
└─ Tests/
   └─ PersistenceTests/
      ├─ Core/
      │  ├─ PersistenceContainerTests.swift
      │  ├─ PersistenceConfigurationTests.swift
      │  ├─ PersistenceMigrationPlanTests.swift
      │  ├─ CoreDataStackTests.swift
      │  └─ CoreDataMigrationTests.swift
      ├─ Stores/
      │  ├─ SearchHistoryStoreTests.swift
      │  ├─ FavoriteStoreTests.swift
      │  ├─ SessionSnapshotStoreTests.swift
      │  ├─ AuthSessionStoreTests.swift
      │  ├─ CacheStoreTests.swift
      │  └─ SyncStateStoreTests.swift
      ├─ Mappers/
      │  ├─ SearchHistoryRecordMapperTests.swift
      │  ├─ FavoriteRecordMapperTests.swift
      │  ├─ SessionSnapshotMapperTests.swift
      │  ├─ AuthSessionRecordMapperTests.swift
      │  ├─ CacheEntryMapperTests.swift
      │  └─ SyncStateRecordMapperTests.swift
      ├─ Records/
      │  ├─ SearchHistoryRecordTests.swift
      │  ├─ FavoriteRecordTests.swift
      │  ├─ SessionSnapshotTests.swift
      │  ├─ CacheEntryTests.swift
      │  └─ SyncStateRecordTests.swift
      └─ TestDoubles/
         └─ Fakes/
            ├─ InMemoryCoreDataStack.swift
            └─ InMemoryManagedObjectContext.swift
```

---

**빠른 시작**

`PersistenceContainer.makeDefault()`로 실 서비스 컨테이너를 초기화한 뒤, 필요한 Store를 즉시 사용할 수 있습니다.

```swift
import Persistence

let container = try await PersistenceContainer.makeDefault()
let store = container.makeSearchHistoryStore()

// 저장
try await store.save(
    SearchHistoryRecord(keyword: "swiftui", lastSearchedAt: Date())
)

// 전체 조회 (lastSearchedAt 내림차순)
let records = try await store.fetchAll()

// 키워드 필터 조회 (대소문자 무시, 부분 일치)
let filtered = try await store.fetchRecords(matching: "swift")
```

테스트나 샘플 실행처럼 디스크 저장소가 필요 없는 환경에서는 in-memory 구성을 사용합니다.

```swift
import Persistence

let container = try await PersistenceContainer.makeDefaultProgrammaticInMemory()
let store = container.makeFavoriteStore()

try await store.save(
    FavoriteRecord(id: "100", type: "movie", createdAt: Date())
)
```

특정 경로와 모델 공급 방식을 직접 제어하려면 설정 객체를 먼저 생성합니다.

```swift
import Persistence

let configuration = try PersistenceConfiguration.live(
    modelSource: ProgrammaticPersistenceModel.defaultSource(),
    directoryName: "MyApp",
    fileName: "MyApp.sqlite",
    migrationPlan: .lightweight
)
let container = try await PersistenceContainer.make(configuration: configuration)
```

---

**핵심 설계 방향**

- **외부 공개 계약과 내부 Core Data 구현 분리**
  상위 계층은 `Records`, `Stores`에만 의존합니다.
  `NSManagedObject`, `NSFetchRequest`, `NSPersistentContainer`, `ContextExecutor` 같은 Core Data 구현 세부는 내부에 감춥니다.

- **조립 지점 통일**
  앱 또는 상위 모듈은 `PersistenceContainer`를 통해 저장소를 초기화합니다.
  6개 저장 도메인이 모두 같은 `CoreDataStack` 위에서 동작합니다.

- **도메인별 책임 분리**
  - 검색 기록: `CoreDataSearchHistoryStore`
  - 즐겨찾기: `CoreDataFavoriteStore`
  - 인증 세션: `CoreDataAuthSessionStore`
  - 세션 스냅샷: `CoreDataSessionSnapshotStore`
  - 캐시: `CoreDataCacheStore`
  - 동기화 상태: `CoreDataSyncStateStore`
  - 값 변환: `Mappers`

- **테스트 친화적인 구조**
  bundle model과 programmatic model을 모두 지원합니다.
  in-memory store를 쉽게 구성할 수 있어 단위 테스트와 샘플 실행에 유리합니다.

---

**PersistenceContainer**

`PersistenceContainer`는 Persistence 모듈의 **조립 진입점(composition entry point)** 입니다.

제공 팩토리:
- `make(configuration:)` — 커스텀 설정 기반 컨테이너
- `makeDefault()` — bundle 모델 + 디스크 기반 SQLite 컨테이너
- `makeDefaultProgrammaticInMemory()` — 코드 기반 모델 + in-memory 컨테이너

제공 메서드:
- `makeSearchHistoryStore() -> any SearchHistoryStoreProtocol`
- `makeFavoriteStore() -> any FavoriteStoreProtocol`
- `makeSessionSnapshotStore() -> any SessionSnapshotStoreProtocol`
- `makeAuthSessionStore() -> any AuthSessionStoreProtocol`
- `makeCacheStore() -> any CacheStoreProtocol`
- `makeSyncStateStore() -> any SyncStateStoreProtocol`

```swift
let container = try await PersistenceContainer.makeDefault()

let searchHistoryStore = container.makeSearchHistoryStore()
let cacheStore = container.makeCacheStore()
let authSessionStore = container.makeAuthSessionStore()
```

컨테이너가 내부적으로 같은 `CoreDataStack`을 재사용하는 구현체를 조립합니다.
`make*Store()`는 해당 도메인 전용 `CoreData*Store`를 같은 stack 위에 조립해 반환합니다.

---

**PersistenceConfiguration**

`PersistenceConfiguration`은 저장소 초기화에 필요한 값을 한 곳에 모아 관리하는 설정 객체입니다.

주요 설정 항목:
- `modelSource` — bundle model 또는 programmatic model
- `storeKind` — SQLite 또는 in-memory
- `isReadOnly`
- `shouldAddStoreAsynchronously`
- `migrationPlan`
- `viewContextAutomaticallyMergesChangesFromParent`
- `viewContextMergePolicy`
- `backgroundContextMergePolicy`

생성 방법:
- `live(...)`: 디스크 기반 SQLite 저장소
- `inMemory(...)`: 메모리 기반 저장소

```swift
// 디스크 기반 — bundle 모델 사용
let configuration = try PersistenceConfiguration.live(
    directoryName: "Persistence",
    fileName: "Persistence.sqlite"
)

// 디스크 기반 — programmatic 모델 사용
let configuration = try PersistenceConfiguration.live(
    modelSource: ProgrammaticPersistenceModel.defaultSource(),
    directoryName: "Persistence",
    fileName: "Persistence.sqlite"
)

// in-memory
let configuration = PersistenceConfiguration.inMemory(
    modelSource: ProgrammaticPersistenceModel.defaultSource()
)
```

---

**모델 공급 방식**

Persistence는 Core Data 모델을 두 가지 방식으로 준비할 수 있습니다.

### bundle model
`.xcdatamodeld`, `.mom`, `.momd` 같은 번들 리소스를 사용하는 방식입니다.

적합한 경우:
- 실제 앱 운영 환경
- Xcode 모델 편집기와 버전 관리 기능 사용
- migration 이력 관리

### programmatic model
코드로 `NSManagedObjectModel`을 직접 생성하는 방식입니다.
`ProgrammaticPersistenceModel.defaultSource()`가 기본 6개 엔티티 구성을 반환합니다.

적합한 경우:
- 단위 테스트 (번들 리소스 의존성 제거)
- 리소스 번들 없이 빠른 실행 확인
- 모델 구조를 코드로 직접 제어하고 싶은 경우

**두 모델의 엔티티명, 속성명, 타입, optional 여부, default value, uniqueness constraint는 반드시 동일해야 합니다.**

| 파일 | 경로 |
|---|---|
| bundle 모델 | `Sources/Persistence/Resources/PersistenceModel.xcdatamodeld` |
| programmatic 모델 | `Sources/Persistence/Core/ProgrammaticPersistenceModel.swift` |

---

**Migration**

`PersistenceMigrationPlan`은 persistent store를 열 때 적용할 migration 정책을 정의합니다.
Core Data `NSPersistentStoreDescription`의 두 migration 옵션을 값 객체로 캡슐화합니다.

기본 제공 정책:

### lightweight
- automatic migration 사용 (`shouldMigrateStoreAutomatically = true`)
- inferred mapping model 사용 (`shouldInferMappingModelAutomatically = true`)
- 속성 추가, optional 변경처럼 Core Data가 자동 추론 가능한 변경에 적합
- Persistence 모듈의 기본 migration 정책

### disabled
- migration 미수행 (`shouldMigrateStoreAutomatically = false`)
- 현재 모델과 기존 store가 호환되지 않으면 store 로딩 실패
- 이미 준비된 스키마를 외부에서 별도로 관리하는 환경에서 사용

```swift
let configuration = try PersistenceConfiguration.live(
    migrationPlan: .lightweight
)
```

migration 정책을 결정하는 곳은 `PersistenceConfiguration`입니다.
`CoreDataStack`은 이미 준비된 store description을 기준으로 persistent store를 로드합니다.

---

**현재 구현 저장소**

### 1. SearchHistory

최근 검색 기록을 저장하는 저장소입니다.

- `keyword` uniqueness constraint — 같은 keyword 재저장 시 `lastSearchedAt` 갱신
- keyword 앞뒤 공백 정규화 저장
- 빈 keyword 저장 차단
- 전체 조회: `lastSearchedAt` 내림차순, 동일 시각이면 `keyword` 오름차순
- keyword 필터 조회: 대소문자 무시, 부분 일치 (`CONTAINS[cd]`)
- 개별 삭제 (`keyword`) / 전체 삭제

관련 구현: `CoreDataSearchHistoryStore`, `SearchHistoryRecord`, `SearchHistoryRecordManagedObject`, `SearchHistoryRecordMapper`

### 2. Favorite

즐겨찾기 항목을 저장하는 저장소입니다.

- `id + type` 조합 uniqueness constraint — 동일 조합 재저장 시 `createdAt` 갱신
- id, type 앞뒤 공백 정규화 저장
- 빈 id 또는 type 저장 차단
- 전체 조회: `createdAt` 내림차순, 동일 시각이면 `type` → `id` 오름차순
- 타입별 조회, 단건 조회 지원
- 개별 삭제 (`id`, `type`) / 전체 삭제

관련 구현: `CoreDataFavoriteStore`, `FavoriteRecord`, `FavoriteRecordManagedObject`, `FavoriteRecordMapper`

### 3. AuthSession

로그인 성공 후 사용자 기본 정보를 저장하는 저장소입니다.

- `environment` uniqueness constraint — 같은 환경 재저장 시 전체 값 갱신
- 문자열 값 앞뒤 공백 정규화 저장
- 필수 값 빈 문자열 저장 차단
- 전체 조회: `environment` 오름차순
- 환경별 단건 조회 지원
- 개별 삭제 (`environment`) / 전체 삭제

**저장 대상**: `environment`, `userID(Int64)`, `email`, `nickname`, `role`, `status`, `isLoggedIn`, `lastRefreshedAt`
**저장 금지**: `accessToken`, `refreshToken`, 토큰 만료 시각, 비밀번호

관련 구현: `CoreDataAuthSessionStore`, `AuthSessionRecord`, `AuthSessionRecordManagedObject`, `AuthSessionRecordMapper`

### 4. SessionSnapshot

환경별 간단 세션 스냅샷을 저장하는 저장소입니다.

- `environment` uniqueness constraint — 같은 환경 재저장 시 전체 값 갱신
- `userID` 공백 정규화 — 빈 문자열이면 `nil`로 저장
- 전체 조회: `environment` 오름차순
- 환경별 단건 조회 지원
- 개별 삭제 (`environment`) / 전체 삭제

관련 구현: `CoreDataSessionSnapshotStore`, `SessionSnapshot`, `SessionSnapshotManagedObject`, `SessionSnapshotMapper`

### 5. Cache

namespace + key 기반 캐시 항목을 저장하는 저장소입니다.

- `namespace + key` 조합 uniqueness constraint — 동일 조합 재저장 시 전체 값 갱신
- namespace, key, eTag 앞뒤 공백 정규화 — 빈 eTag는 `nil`로 저장
- 빈 namespace 또는 key 저장 차단
- 전체 조회: `namespace` → `key` 오름차순
- namespace별 목록 조회, 단건 조회 지원
- 개별 삭제, namespace 단위 삭제, 전체 삭제 지원

관련 구현: `CoreDataCacheStore`, `CacheEntry`, `CacheEntryManagedObject`, `CacheEntryMapper`

### 6. SyncState

namespace별 동기화 상태와 커서를 저장하는 저장소입니다.

- `namespace` uniqueness constraint — 같은 namespace 재저장 시 전체 값 갱신
- `cursor` 공백 정규화 — 빈 문자열이면 `nil`로 저장
- 빈 namespace 저장 차단
- 전체 조회: `namespace` 오름차순
- namespace별 단건 조회 지원
- 개별 삭제 (`namespace`) / 전체 삭제

관련 구현: `CoreDataSyncStateStore`, `SyncStateRecord`, `SyncStateRecordManagedObject`, `SyncStateRecordMapper`

---

**공개 모델과 계약**

### Records

| 타입 | 저장 필드 |
|---|---|
| `SearchHistoryRecord` | `keyword`, `lastSearchedAt` |
| `FavoriteRecord` | `id`, `type`, `createdAt` |
| `AuthSessionRecord` | `environment`, `userID(Int64)`, `email`, `nickname`, `role`, `status`, `isLoggedIn`, `lastRefreshedAt` |
| `SessionSnapshot` | `environment`, `isLoggedIn`, `lastRefreshedAt?`, `userID?` |
| `CacheEntry` | `namespace`, `key`, `payload(Data)`, `eTag?`, `expiresAt?`, `createdAt`, `version` |
| `SyncStateRecord` | `namespace`, `cursor?`, `isDirty`, `lastSyncedAt?` |

모든 Record는 `Equatable`, `Sendable`을 채택한 `struct`입니다.

### Store Protocols

```swift
public protocol SearchHistoryStoreProtocol {
    func fetchAll() async throws -> [SearchHistoryRecord]
    func fetchRecords(matching keyword: String) async throws -> [SearchHistoryRecord]
    func save(_ record: SearchHistoryRecord) async throws
    func delete(keyword: String) async throws
    func deleteAll() async throws
}

public protocol FavoriteStoreProtocol {
    func fetchAll() async throws -> [FavoriteRecord]
    func fetchRecords(ofType type: String) async throws -> [FavoriteRecord]
    func fetchRecord(id: String, type: String) async throws -> FavoriteRecord?
    func save(_ record: FavoriteRecord) async throws
    func delete(id: String, type: String) async throws
    func deleteAll() async throws
}

public protocol AuthSessionStoreProtocol {
    func fetchAll() async throws -> [AuthSessionRecord]
    func fetchSession(for environment: String) async throws -> AuthSessionRecord?
    func save(_ session: AuthSessionRecord) async throws
    func delete(environment: String) async throws
    func deleteAll() async throws
}

public protocol SessionSnapshotStoreProtocol {
    func fetchAll() async throws -> [SessionSnapshot]
    func fetchSnapshot(for environment: String) async throws -> SessionSnapshot?
    func save(_ snapshot: SessionSnapshot) async throws
    func delete(environment: String) async throws
    func deleteAll() async throws
}

public protocol CacheStoreProtocol {
    func fetchAll() async throws -> [CacheEntry]
    func fetchEntries(in namespace: String) async throws -> [CacheEntry]
    func fetchEntry(namespace: String, key: String) async throws -> CacheEntry?
    func save(_ entry: CacheEntry) async throws
    func delete(namespace: String, key: String) async throws
    func deleteEntries(in namespace: String) async throws
    func deleteAll() async throws
}

public protocol SyncStateStoreProtocol {
    func fetchAll() async throws -> [SyncStateRecord]
    func fetchRecord(for namespace: String) async throws -> SyncStateRecord?
    func save(_ record: SyncStateRecord) async throws
    func delete(namespace: String) async throws
    func deleteAll() async throws
}
```

### Errors

`PersistenceError` 주요 케이스:
- `invalidConfiguration(String)` — 설정값 오류 또는 필수 값 누락
- `modelNotFound(modelName:bundlePath:)` — 번들에서 Core Data 모델을 찾지 못한 경우
- `persistentStoreLoadFailed(String)` — persistent store 연결 또는 로딩 실패
- `readFailed(String)` — background context 읽기 작업 실패
- `writeFailed(String)` — background context 쓰기 또는 save 실패

상위 계층은 Foundation/Core Data의 원시 에러 타입을 직접 해석하지 않고 `PersistenceError`를 기준으로 실패를 분류합니다.

---

**내부 계층 구성**

### Core
모듈 기반 인프라를 담당합니다.

- `PersistenceContainer`: 조립 진입점
- `PersistenceConfiguration`: 설정값 (모델 공급, 저장소 종류, merge policy, migration)
- `PersistenceMigrationPlan`: migration 정책 값 객체
- `ProgrammaticPersistenceModel`: 코드 기반 기본 모델 생성
- `CoreDataStack`: `NSPersistentContainer` 초기화, context 관리
- `CoreDataStackProtocol`: stack 계약 (테스트 더블 교체 지점)
- `ContextExecutor`: background context 읽기/쓰기 실행 추상화

### Records
SQLite row 결과를 내부에서 다루는 `NSManagedObject` 서브클래스입니다.
- `SearchHistoryRecordManagedObject`
- `FavoriteRecordManagedObject`
- `AuthSessionRecordManagedObject`
- `SessionSnapshotManagedObject`
- `CacheEntryManagedObject`
- `SyncStateRecordManagedObject`

### Mappers
`NSManagedObject`와 공개 Record 사이를 변환합니다.
- `SearchHistoryRecordMapper`
- `FavoriteRecordMapper`
- `AuthSessionRecordMapper`
- `SessionSnapshotMapper`
- `CacheEntryMapper`
- `SyncStateRecordMapper`

### CoreDataStores
실제 Core Data 저장/조회 로직을 구현합니다.
- `CoreDataSearchHistoryStore`
- `CoreDataFavoriteStore`
- `CoreDataAuthSessionStore`
- `CoreDataSessionSnapshotStore`
- `CoreDataCacheStore`
- `CoreDataSyncStateStore`

---

**Core Data foundation**

Core 계층은 Core Data 기반 foundation을 담당합니다.

- `CoreDataStack`: `NSPersistentContainer` 초기화, `viewContext` 설정, background context 생성
- `ContextExecutor`: `performRead(_:)` / `performWrite(_:)` 통해 background context 실행 경계 관리
- `ProgrammaticPersistenceModel`: 6개 엔티티 코드 정의

Core Data 엔티티 uniqueness 정책:

| 엔티티 | Uniqueness Constraint |
|---|---|
| `SearchHistoryRecord` | `keyword` |
| `FavoriteRecord` | `["id", "type"]` |
| `AuthSessionRecord` | `environment` |
| `SessionSnapshot` | `environment` |
| `CacheEntry` | `["namespace", "key"]` |
| `SyncStateRecord` | `namespace` |

모든 저장 작업은 background context에서 수행되며, merge policy 기본값은 `objectTrump`입니다.

---

**테스트**

모듈은 in-memory Core Data 환경을 활용한 테스트를 포함합니다.

포함된 테스트 범위:
- Core foundation: `CoreDataStackTests`, `PersistenceConfigurationTests`, `PersistenceMigrationPlanTests`, `PersistenceContainerTests`, `CoreDataMigrationTests`
- Stores: `SearchHistoryStoreTests`, `FavoriteStoreTests`, `AuthSessionStoreTests`, `SessionSnapshotStoreTests`, `CacheStoreTests`, `SyncStateStoreTests`
- Mappers: `SearchHistoryRecordMapperTests`, `FavoriteRecordMapperTests`, `AuthSessionRecordMapperTests`, `SessionSnapshotMapperTests`, `CacheEntryMapperTests`, `SyncStateRecordMapperTests`
- Records: `SearchHistoryRecordTests`, `FavoriteRecordTests`, `CacheEntryTests`, `SyncStateRecordTests`

테스트 전략:
- Store 테스트는 `ProgrammaticPersistenceModel.defaultSource()` 기반 in-memory Core Data를 사용합니다.
- 각 테스트는 독립된 `PersistenceContainer`를 생성해 상태를 격리합니다.
- 실제 디스크 I/O, 실제 SQLite 파일은 테스트에서 사용하지 않습니다.
- Core foundation 테스트와 Store 기능 테스트를 분리합니다.
- upsert 정책, 공백 정규화, 정렬 규칙, 개별/전체 삭제 동작을 단위 테스트로 고정합니다.

---

**권장 사용 전략**
- 상위 계층은 `PersistenceContainer`와 공개 Store Protocol을 기준으로 의존성을 설계합니다.
- AppData Repository는 `*StoreProtocol` 계약을 주입받아 로컬 저장소에 접근합니다.
- `NSManagedObject`, `Mapper`, `CoreDataStack`, `ContextExecutor` 직접 의존은 Persistence 내부에 제한합니다.
- 운영 환경은 `live`, 테스트와 샘플 실행은 `inMemory`를 우선 사용합니다.
- migration 정책은 `PersistenceMigrationPlan`으로 환경별 분리 구성을 권장합니다.

---

**권장 확장 방식**
1. `Records`에 공개 Record 추가
2. `Stores`에 Store Protocol 추가
3. `ManagedObjects`에 `NSManagedObject` 서브클래스 추가
4. `Mappers`에 Mapper 추가
5. `CoreDataStores`에 구현체 추가
6. `PersistenceContainer`에 `make*Store()` 팩토리 메서드 추가
7. `ProgrammaticPersistenceModel.swift`와 `PersistenceModel.xcdatamodeld`에 엔티티 반영 (두 파일 동시 갱신 필수)
8. Store 테스트, Mapper 테스트, Record 테스트 추가

---

Created by: JEONG, Chi-hong
Updated: May 2026
