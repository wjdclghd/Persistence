//
//  RealmSwiftDBSearchListEntityMapping.swift
//  CoreDatabase
//
//  Created by jch on 6/30/25.
//

import Foundation
import RealmSwift

public class RealmSwiftDBSearchListEntityMapping: Object {
    @Persisted(primaryKey: true) var key: String
    @Persisted var searchKeyword: String
    @Persisted var timestamp: Date
    
    convenience init(key: String, searchKeyword: String, timestamp: Date = Date()) {
        self.init()
        self.key = key
        self.searchKeyword = searchKeyword
        self.timestamp = timestamp
    }
}

public extension RealmSwiftDBSearchListEntityMapping {
    func toSearchListEntity<T: RealmSwiftDBSearchListEntityProtocol>() -> T {
        T(searchKeyword: searchKeyword)
    }
    
    convenience init<T: RealmSwiftDBSearchListEntityProtocol>(searchListEntity: T, key: String = "RealmSwiftDBSearch : \(UUID().uuidString)", timestamp: Date = Date()) {
        self.init()
        self.key = key
        self.searchKeyword = searchListEntity.searchKeyword
        self.timestamp = timestamp
    }
}
