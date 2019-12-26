//
//  database.swift
//  macOSBackup
//
//  Created by Сергей Петров on 26.12.2019.
//  Copyright © 2019 SergioPetrovx. All rights reserved.
//

import Foundation
import SQLite3

// MARK: Database
class Database {
    
    let dbUrl : URL
    var db : OpaquePointer?
    var statement : OpaquePointer?
    public static var shared = Database()
    
    private init() {
        dbUrl = try! FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false).appendingPathComponent("macOSBackupDatabase.sqlite")

        if sqlite3_open(dbUrl.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
        tableInit()
    }
    
    func tableInit() {
        let query = "CREATE TABLE IF NOT EXISTS BackupInfo (BackupName varchar(64) primary key, dedDate integer, dadDate integer, sonDate integer, dadState integer, sonState integer); "
        
        if sqlite3_exec(db, query, nil, nil, nil) != SQLITE_OK {
            print("Error creating Tables!")
        }
    }
    
    func addNewItem(info: BackupInfo) {
        let query = "INSERT INTO BackupInfo (BackupName, dedDate, dadDate, sonDate, dadState, sonState) VALUES (?, ?, ?, ?, ?, ?)"
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, info.hashName, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(info.dedDate.timeIntervalSince1970))
            sqlite3_bind_int(statement, 3, Int32(info.dadDate.timeIntervalSince1970))
            sqlite3_bind_int(statement, 4, Int32(info.sonDate.timeIntervalSince1970))
            sqlite3_bind_int(statement, 5, 1)
            sqlite3_bind_int(statement, 6, 1)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error add new item to database!")
            }
        }
    }
    
    func updateDate(name: String, date: Date, type: BackupInfo.BackupType) {
        var mode = ""
        switch type.rawValue {
        case 1:
            mode="dedDate"
        case 2:
            mode="dadDate"
        case 3:
            mode="sonDate"
        default: ()
        }
        let query = "UPDATE BackupInfo SET \(mode)=? WHERE BackupName=?"
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(date.timeIntervalSince1970))
            sqlite3_bind_text(statement, 2, name, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error update database!")
            }
        }
    }
    
    func getDate(name: String, type: BackupInfo.BackupType) -> Int? {
        var date: Int?
        var mode = ""
        switch type.rawValue {
        case 1:
            mode="dedDate"
        case 2:
            mode="dadDate"
        case 3:
            mode="sonDate"
        default: ()
        }
        let query = "SELECT \(mode) FROM BackupInfo WHERE BackupName=?"
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, name, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                date = Int(sqlite3_column_int(statement, 0))
            }
        }
        return date
    }
    
    func updateState(name: String, type: BackupInfo.BackupType, state: Int) {
        var mode = ""
        switch type.rawValue {
        case 2:
            mode="dadState"
        case 3:
            mode="sonState"
        default: ()
        }
        let query = "UPDATE BackupInfo SET \(mode)=? WHERE BackupName=?"
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(state))
            sqlite3_bind_text(statement, 2, name, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error update database!")
            }
        }
    }
    
    func getState(name: String, type: BackupInfo.BackupType) -> Int? {
        var state: Int?
        var mode = ""
        switch type.rawValue {
        case 2:
            mode="dadState"
        case 3:
            mode="sonState"
        default: ()
        }
        let query = "SELECT \(mode) FROM BackupInfo WHERE BackupName=?"
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, name, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                state = Int(sqlite3_column_int(statement, 0))
            }
        }
        return state
    }
}
