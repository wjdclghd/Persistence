//
//  RealmSwiftDBSearchListProtocol.swift
//  CoreDatabase
//
//  Created by jch on 6/30/25.
//

import Foundation
import Combine

public protocol RealmSwiftDBSearchListProtocol {
    func insertDatabase<T: RealmSwiftDBSearchListEntityProtocol>(searchListEntity: T) -> AnyPublisher<Void, Error>
    func updateDatabase<T: RealmSwiftDBSearchListEntityProtocol>(searchListEntity: T) -> AnyPublisher<[T], Error>
    func deleteDatabase(searchKeyword: String) -> AnyPublisher<Void, Error>
    func deleteAllDatabase() -> AnyPublisher<Void, Error>
    func selectDatabase<T: RealmSwiftDBSearchListEntityProtocol>(searchKeyword: String) -> AnyPublisher<[T], Error>
    func selectAllDatabase<T: RealmSwiftDBSearchListEntityProtocol>() -> AnyPublisher<[T], Error>
}
