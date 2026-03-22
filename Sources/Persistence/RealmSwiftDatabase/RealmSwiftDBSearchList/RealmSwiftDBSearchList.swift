//
//  RealmSwiftDBSearchList.swift
//  CoreDatabase
//
//  Created by jch on 6/30/25.
//

import Foundation
import RealmSwift
import Combine

public final class RealmSwiftDBSearchList: RealmSwiftDBSearchListProtocol {
    private let realmDatabase: Realm

    public init(realmDatabase: Realm) {
        self.realmDatabase = realmDatabase
    }

    public convenience init() throws {
        let config = Realm.Configuration(
            fileURL: try RealmSwiftDBMigration.searchRealmURL(),
            schemaVersion: RealmSwiftDBMigration.schemaVersion,
            migrationBlock: RealmSwiftDBMigration.migrationBlock
        )
        
        self.init(realmDatabase: try Realm(configuration: config))
    }

    public func insertDatabase<T: RealmSwiftDBSearchListEntityProtocol>(searchListEntity: T) -> AnyPublisher<Void, Error> {
        Deferred {
            Future { completion in
                do {
                    try self.realmDatabase.write {
                        let searchKeyword = RealmSwiftDBSearchListEntityMapping(searchListEntity: searchListEntity)
                        
                        self.realmDatabase.add(searchKeyword, update: .modified)
                    }
                    
                    completion(.success(()))
                } catch {
                    completion(.failure(RealmSwiftDBError.databaseError(error)))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    public func updateDatabase<T: RealmSwiftDBSearchListEntityProtocol>(searchListEntity: T) -> AnyPublisher<[T], Error> {
        Deferred {
            Future { completion in
                do {
                    try self.realmDatabase.write {
                        let searchKeyword = self.realmDatabase.objects(RealmSwiftDBSearchListEntityMapping.self)
                            .filter("searchKeyword == %@", searchListEntity.searchKeyword)

                        if let first = searchKeyword.first {
                            first.timestamp = Date()
                        } else {
                            let newSearchKeyword = RealmSwiftDBSearchListEntityMapping(searchListEntity: searchListEntity)
                            
                            self.realmDatabase.add(newSearchKeyword, update: .modified)
                        }
                    }

                    let updateSearchKeyword = Array(self.realmDatabase.objects(RealmSwiftDBSearchListEntityMapping.self)
                        .sorted(byKeyPath: "timestamp", ascending: false)
                        .map { $0.toSearchListEntity() as T })

                    completion(.success(updateSearchKeyword))
                } catch {
                    completion(.failure(RealmSwiftDBError.databaseError(error)))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    public func deleteDatabase(searchKeyword: String) -> AnyPublisher<Void, Error> {
        Deferred {
            Future { completion in
                do {
                    try self.realmDatabase.write {
                        let deleteSearchKeyword = self.realmDatabase.objects(RealmSwiftDBSearchListEntityMapping.self)
                            .filter("searchKeyword == %@", searchKeyword)
                        
                        self.realmDatabase.delete(deleteSearchKeyword)
                    }
                    completion(.success(()))
                } catch {
                    completion(.failure(RealmSwiftDBError.databaseError(error)))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    public func deleteAllDatabase() -> AnyPublisher<Void, Error> {
        Deferred {
            Future { completion in
                do {
                    try self.realmDatabase.write {
                        self.realmDatabase.deleteAll()
                    }
                    
                    completion(.success(()))
                } catch {
                    completion(.failure(RealmSwiftDBError.databaseError(error)))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    public func selectDatabase<T: RealmSwiftDBSearchListEntityProtocol>(searchKeyword: String) -> AnyPublisher<[T], Error> {
        Just(())
            .tryMap {
                let selectSearchKeyword = self.realmDatabase.objects(RealmSwiftDBSearchListEntityMapping.self)
                    .filter("searchKeyword CONTAINS[c] %@", searchKeyword)
                    .sorted(byKeyPath: "timestamp", ascending: false)
                
                return selectSearchKeyword.map { $0.toSearchListEntity() as T }
            }
            .mapError { RealmSwiftDBError.databaseError($0) }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    public func selectAllDatabase<T: RealmSwiftDBSearchListEntityProtocol>() -> AnyPublisher<[T], Error> {
        Just(())
            .tryMap {
                let selectAllSearchKeyword = self.realmDatabase.objects(RealmSwiftDBSearchListEntityMapping.self)
                    .sorted(byKeyPath: "timestamp", ascending: false)
                
                return selectAllSearchKeyword.map { $0.toSearchListEntity() as T }
            }
            .mapError { RealmSwiftDBError.databaseError($0) }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
