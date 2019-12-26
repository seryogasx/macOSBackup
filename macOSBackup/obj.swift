//
//  obj.swift
//  macOSBackup
//
//  Created by Сергей Петров on 26.12.2019.
//  Copyright © 2019 SergioPetrovx. All rights reserved.
//

import Foundation
import CryptoKit

extension String {
    var sha256: String {
        String(SHA256.hash(data: Data(self.utf8)).description.suffix(64))
    }
}


// MARK: Item
struct Item {
    let modificationDate: Date
    let fullPath: String
    let name: String
}


// MARK: BackuperError
enum BackuperError: Error {
    case itemNotExists(path: String)
    case itemAlreadyExists(path: String)
    case emptyBackup
}


// MARK: BackupState
struct BackupInfo {
    
    enum BackupType: Int {
        case ded = 1
        case dad = 2
        case son = 3
    }
    var hashName: String
    var dedDate: Date
    var dadDate: Date
    var sonDate: Date
}
