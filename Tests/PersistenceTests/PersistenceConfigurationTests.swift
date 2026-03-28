//
//  PersistenceConfigurationTests.swift
//  Persistence
//
//  Created by jch on 3/28/26.
//

import Foundation
import XCTest
@testable import Persistence

/*
 PersistenceConfiguration의 기본 설정값과 검증 동작을 확인하는 테스트입니다.

 이 테스트는 환경별 팩토리 메서드가 올바른 store 종류를 선택하는지,
 bundle 기반 모델과 programmatic 모델을 모두 담을 수 있는지,
 SQLite 저장소 URL이 예상한 위치에 생성되는지,
 필수 문자열 값이 비어 있을 때 명확한 설정 오류가 반환되는지를 검증합니다.
 */
final class PersistenceConfigurationTests: XCTestCase {
    /*
     inMemory 설정이 in-memory store를 사용하도록 구성되는지 검증합니다.

     테스트 환경에서는 디스크 저장소 대신 in-memory store를 사용해야 하므로,
     storeKind가 정확히 .inMemory로 설정되는지를 확인합니다.
     */
    func test_inMemoryConfiguration_usesInMemoryStore() {
        let configuration = PersistenceConfiguration.inMemory()

        guard case .inMemory = configuration.storeKind else {
            return XCTFail("Expected in-memory store")
        }
    }

    /*
     programmatic 모델을 전달한 inMemory 설정도 올바르게 보관되는지 검증합니다.

     설정 객체가 모델 공급 방식을 유지하고,
     모델 이름을 공통 프로퍼티로 노출하는지 확인합니다.
     */
    func test_inMemoryConfiguration_withProgrammaticModel_keepsModelSource() {
        let configuration = PersistenceConfiguration.inMemory(
            modelSource: ProgrammaticPersistenceModel.defaultSource(modelName: "ProgrammaticModel")
        )

        guard case .programmatic(let modelName, _) = configuration.modelSource else {
            return XCTFail("Expected programmatic model source")
        }

        XCTAssertEqual(modelName, "ProgrammaticModel")
        XCTAssertEqual(configuration.modelName, "ProgrammaticModel")
    }

    /*
     live 설정이 지정한 기준 디렉터리 아래에 SQLite 파일 URL을 생성하는지 검증합니다.

     테스트에서는 Application Support를 직접 사용하지 않고,
     임시 디렉터리를 기준 경로로 주입하여 파일 시스템 부작용을 줄입니다.
     생성된 URL이 sqlite 확장자를 가지며 디렉터리 경로 규칙이 유지되는지를 확인합니다.
     */
    func test_liveConfiguration_createsSQLiteURL() throws {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        defer {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }

        let configuration = try PersistenceConfiguration.live(
            directoryName: "Persistence",
            fileName: "Persistence.sqlite",
            baseDirectoryURL: temporaryDirectoryURL
        )

        guard case let .sqlite(url) = configuration.storeKind else {
            return XCTFail("Expected sqlite store")
        }

        XCTAssertEqual(url.pathExtension, "sqlite")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "Persistence")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path)
        )
    }

    /*
     programmatic 모델을 사용한 live 설정도 SQLite 저장소 URL을 생성할 수 있는지 검증합니다.

     모델 공급 방식과 저장소 종류가 서로 독립적으로 조합될 수 있어야 하므로,
     코드 기반 모델과 디스크 저장소의 조합을 확인합니다.
     */
    func test_liveConfiguration_withProgrammaticModel_createsSQLiteURL() throws {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        defer {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }

        let configuration = try PersistenceConfiguration.live(
            modelSource: ProgrammaticPersistenceModel.defaultSource(),
            directoryName: "Persistence",
            fileName: "Persistence.sqlite",
            baseDirectoryURL: temporaryDirectoryURL
        )

        guard case let .sqlite(url) = configuration.storeKind else {
            return XCTFail("Expected sqlite store")
        }

        XCTAssertEqual(configuration.modelName, "PersistenceModel")
        XCTAssertEqual(url.pathExtension, "sqlite")
    }

    /*
     live 설정에서 필수 문자열 값이 비어 있으면 invalidConfiguration이 발생하는지 검증합니다.

     저장소 경로를 만들기 전에 잘못된 설정을 차단하면,
     파일 시스템 작업 중 발생하는 모호한 오류 대신 명확한 원인을 전달할 수 있습니다.
     */
    func test_liveConfiguration_withEmptyDirectoryName_throwsInvalidConfiguration() {
        XCTAssertThrowsError(
            try PersistenceConfiguration.live(directoryName: " ")
        ) { error in
            guard case let PersistenceError.invalidConfiguration(message) = error else {
                return XCTFail("Expected invalidConfiguration, got \(error)")
            }

            XCTAssertFalse(message.isEmpty)
        }
    }
}
