//
//  RealmSwiftDBMigration.swift
//  CoreDatabase
//
//  Created by jch on 6/30/25.
//
/*
import Foundation
import RealmSwift

public final class RealmSwiftDBMigration: RealmSwiftDBMigrationProtocol {
    public static let schemaVersion: UInt64 = 0
    
    public static let migrationBlock: MigrationBlock = { migration, oldSchemaVersion in
        
    }
    
    public init() {}
    
    public func configuration() {
        do {
            let searchConfig = Realm.Configuration(
               fileURL: try Self.searchRealmURL(),
                schemaVersion: Self.schemaVersion,
                migrationBlock: Self.migrationBlock
            )
            
            Realm.Configuration.defaultConfiguration = searchConfig
            
            print("Success : Configuration RealmSwiftDBMigration RealmSearchDB, schemaVersion : \(Self.schemaVersion)")
        } catch {
            print("Failed : Configuration RealmSwiftDBMigration RealmSearchDB : \(error)")
        }
    }
     
    public static func searchRealmURL() throws -> URL {
        do {
            let fileManager = FileManager.default
            
            let directory = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let directoryURL = directory.appendingPathComponent("RealmSearchDB.realm")
            
            print("Success : RealmSwiftDBMigration RealmSearchDB URL : \(directoryURL.path)")
            
            return directoryURL
        } catch {
            print("Failed : RealmSwiftDBMigration RealmSearchDB URL : \(error)")
            
            throw error
        }
    }
}
*/
