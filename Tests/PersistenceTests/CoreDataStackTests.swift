//
//  CoreDataStackTests.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
import CoreData
import XCTest
@testable import Persistence

/*
 CoreDataStack의 생성, 저장소 접근, 에러 매핑 동작을 검증하는 테스트입니다.

 이 테스트는 in-memory store를 사용하여 파일 시스템에 영향을 주지 않고,
 CoreDataStack이 정상적으로 초기화되는지,
 bundle 기반 모델과 programmatic 모델 모두에서 실제 Core Data 엔터티를 저장하고 다시 조회할 수 있는지,
 읽기/쓰기 및 설정 오류가 PersistenceError로 올바르게 변환되는지를 확인합니다.
 */
final class CoreDataStackTests: XCTestCase {
    /*
     테스트에서 발생시키는 의도적인 실패를 표현하는 에러 타입입니다.

     performRead와 performWrite가 내부 오류를 PersistenceError로
     올바르게 감싸는지 검증하기 위해 사용합니다.
     */
    private enum TestFailure: Error {
        case expected
    }

    /*
     모델 로딩 실패를 검증할 때 사용할 테스트 번들 토큰입니다.

     Persistence 모델 리소스가 없는 번들을 참조하여,
     잘못된 모델 이름과 번들 조합에서 modelNotFound가 발생하는지 확인합니다.
     */
    private final class TestBundleToken {}

    /*
     엔티티 이름이 없는 programmatic 모델을 만들기 위한 테스트 빌더입니다.

     CoreDataStack이 코드 기반 모델의 최소 유효성을 검사하는지 검증할 때 사용합니다.
     */
    private enum InvalidProgrammaticModelBuilder {
        static func makeUnnamedEntityModel() -> NSManagedObjectModel {
            let model = NSManagedObjectModel()
            let entity = NSEntityDescription()
            entity.name = " "
            entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
            model.entities = [entity]
            return model
        }
    }

    /*
     bundle 기반 in-memory 설정으로 CoreDataStack을 생성할 수 있는지 검증합니다.

     스택 생성이 성공하면 viewContext가 준비되어 있어야 하므로,
     최소한의 초기화가 완료되었는지를 확인하는 시작점 테스트로 사용합니다.
     */
    func test_make_inMemoryStack_succeeds() async throws {
        let stack = try await InMemoryCoreDataStack.make()
        XCTAssertNotNil(stack.viewContext)
    }

    /*
     programmatic 모델 기반 in-memory 설정으로도 CoreDataStack을 생성할 수 있는지 검증합니다.

     리소스 번들을 사용하지 않는 모델 경로가 실제 컨테이너 초기화까지 연결되는지 확인합니다.
     */
    func test_make_inMemoryStack_withProgrammaticModel_succeeds() async throws {
        let stack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )
        XCTAssertNotNil(stack.viewContext)
    }

    /*
     bundle 기반 모델에서 실제 엔터티를 저장한 뒤 다시 조회할 수 있는지 검증합니다.

     SearchHistoryRecord 엔터티를 background context에 삽입하고 save한 뒤
     다시 fetch하여 저장된 데이터가 남아 있는지를 확인합니다.
     */
    func test_performWrite_and_performRead_persistsAndFetchesSearchHistory() async throws {
        let stack = try await InMemoryCoreDataStack.make()

        let fetchedValues = try await persistAndFetchSearchHistory(
            using: stack,
            keyword: "swiftui",
            lastSearchedAt: Date(timeIntervalSince1970: 1_711_644_800)
        )

        XCTAssertEqual(fetchedValues.0, "swiftui")
        XCTAssertEqual(fetchedValues.1, Date(timeIntervalSince1970: 1_711_644_800))
    }

    /*
     programmatic 모델에서도 동일한 엔터티 저장과 조회 흐름이 유지되는지 검증합니다.

     모델 공급 방식만 바꾸더라도 같은 엔티티 이름과 속성 이름으로
     저장 및 조회 로직이 동일하게 동작해야 합니다.
     */
    func test_performWrite_and_performRead_withProgrammaticModel_persistsAndFetchesSearchHistory() async throws {
        let stack = try await InMemoryCoreDataStack.make(
            modelSource: ProgrammaticPersistenceModel.defaultSource()
        )

        let fetchedValues = try await persistAndFetchSearchHistory(
            using: stack,
            keyword: "combine",
            lastSearchedAt: Date(timeIntervalSince1970: 1_711_731_200)
        )

        XCTAssertEqual(fetchedValues.0, "combine")
        XCTAssertEqual(fetchedValues.1, Date(timeIntervalSince1970: 1_711_731_200))
    }

    /*
     읽기 작업 중 발생한 오류가 PersistenceError.readFailed로 변환되는지 검증합니다.

     호출부는 내부 구현 에러를 직접 알 필요 없이
     Persistence 도메인 기준의 읽기 실패로 해석할 수 있어야 합니다.
     */
    func test_performRead_whenBlockThrows_mapsToReadFailed() async throws {
        let stack = try await InMemoryCoreDataStack.make()

        do {
            _ = try await stack.performRead { _ in
                throw TestFailure.expected
            }
            XCTFail("Expected readFailed error")
        } catch let error as PersistenceError {
            guard case let .readFailed(message) = error else {
                return XCTFail("Expected readFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     쓰기 작업 중 발생한 오류가 PersistenceError.writeFailed로 변환되는지 검증합니다.

     삽입, 수정, 삭제 또는 save 이전 단계에서 오류가 발생하더라도,
     호출부는 쓰기 실패라는 동일한 도메인 에러로 처리할 수 있어야 합니다.
     */
    func test_performWrite_whenBlockThrows_mapsToWriteFailed() async throws {
        let stack = try await InMemoryCoreDataStack.make()

        do {
            _ = try await stack.performWrite { _ in
                throw TestFailure.expected
            }
            XCTFail("Expected writeFailed error")
        } catch let error as PersistenceError {
            guard case let .writeFailed(message) = error else {
                return XCTFail("Expected writeFailed, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }

    /*
     필수 설정값이 비어 있는 경우 stack 생성 전에 invalidConfiguration이 발생하는지 검증합니다.

     잘못된 모델 이름이 실제 Core Data 초기화 단계로 넘어가기 전에 차단되면,
     설정 오류와 모델 로딩 오류를 더 명확하게 구분할 수 있습니다.
     */
    func test_make_withEmptyModelName_throwsInvalidConfiguration() async {
        let configuration = PersistenceConfiguration(
            modelName: "  ",
            modelBundle: .module,
            storeKind: .inMemory
        )

        do {
            _ = try await CoreDataStack.make(configuration: configuration)
            XCTFail("Expected invalidConfiguration error")
        } catch let error as PersistenceError {
            guard case let .invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /*
     모델 리소스가 없는 번들을 사용하면 modelNotFound가 발생하는지 검증합니다.

     모델 파일 누락이나 잘못된 번들 지정이 발생했을 때,
     CoreDataStack이 저장소 초기화를 진행하지 않고 명확한 모델 로딩 오류를 반환해야 합니다.
     */
    func test_make_withUnknownModelInDifferentBundle_throwsModelNotFound() async {
        let configuration = PersistenceConfiguration.inMemory(
            modelName: "UnknownModel",
            modelBundle: Bundle(for: TestBundleToken.self)
        )

        do {
            _ = try await CoreDataStack.make(configuration: configuration)
            XCTFail("Expected modelNotFound error")
        } catch let error as PersistenceError {
            guard case let .modelNotFound(modelName, bundlePath) = error else {
                return XCTFail("Expected modelNotFound, got \(error)")
            }

            XCTAssertEqual(modelName, "UnknownModel")
            XCTAssertFalse(bundlePath.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /*
     이름이 없는 엔티티를 포함한 programmatic 모델이 invalidConfiguration으로 차단되는지 검증합니다.

     코드 기반 모델 경로는 번들 리소스 검사가 없으므로,
     최소한의 모델 구조 검증이 실제로 동작하는지 확인합니다.
     */
    func test_make_withInvalidProgrammaticModel_throwsInvalidConfiguration() async {
        let configuration = PersistenceConfiguration.inMemory(
            modelSource: .programmatic(
                modelName: "PersistenceModel",
                makeManagedObjectModel: {
                    InvalidProgrammaticModelBuilder.makeUnnamedEntityModel()
                }
            )
        )

        do {
            _ = try await CoreDataStack.make(configuration: configuration)
            XCTFail("Expected invalidConfiguration error")
        } catch let error as PersistenceError {
            guard case let .invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private extension CoreDataStackTests {
    /*
     SearchHistoryRecord 엔티티를 저장한 뒤 다시 조회하는 공통 검증 로직입니다.

     bundle 기반 모델과 programmatic 모델이 같은 엔티티 이름과 속성 이름을 제공하는지,
     동일한 저장/조회 경로로 확인하기 위해 재사용합니다.
     */
    func persistAndFetchSearchHistory(
        using stack: CoreDataStackProtocol,
        keyword: String,
        lastSearchedAt: Date
    ) async throws -> (String, Date) {
        try await stack.performWrite { context in
            let object = NSEntityDescription.insertNewObject(
                forEntityName: "SearchHistoryRecord",
                into: context
            )
            object.setValue(keyword, forKey: "keyword")
            object.setValue(lastSearchedAt, forKey: "lastSearchedAt")
        }

        return try await stack.performRead { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "SearchHistoryRecord")
            request.fetchLimit = 1
            let objects = try context.fetch(request)
            let object = try XCTUnwrap(objects.first)
            let fetchedKeyword = try XCTUnwrap(object.value(forKey: "keyword") as? String)
            let fetchedDate = try XCTUnwrap(object.value(forKey: "lastSearchedAt") as? Date)
            return (fetchedKeyword, fetchedDate)
        }
    }
}
