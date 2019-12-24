import Foundation
import CryptoKit
import SQLite3


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
        let query = "CREATE TABLE IF NOT EXISTS BackupInfo (BackupName varchar(64) primary key, dedDate integer, dadDate integer, sonDate ineteger); "
        
        if sqlite3_exec(db, query, nil, nil, nil) != SQLITE_OK {
            print("Error creating Tables!")
        }
    }
    
    func addNewItem(info: BackupInfo) {
        let query = "INSERT INTO BackupInfo (BackupName, dedDate, dadDate, sonDate) VALUES (?, ?, ?, ?)"
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, info.hashName, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(info.dedDate.timeIntervalSince1970))
            sqlite3_bind_int(statement, 3, Int32(info.dadDate.timeIntervalSince1970))
            sqlite3_bind_int(statement, 4, Int32(info.sonDate.timeIntervalSince1970))
            
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
}


// MARK: Backuper
class Backuper {
    
    let BACKUP_FOLDER_NAME = "macOSBackup"
    let BACKUP_SON_NAME = "son"
    let BACKUP_DAD_NAME = "dad"
    let BACKUP_DED_NAME = "ded"
    let SON_BACKUP_INTERVAL = 86400
    let DAD_BACKUP_INTERVAL = 86400 * 7
    let DED_BACKUP_INTERVAL = 86400 * 28
    private var backupItemsList: [Item] = []
    private let backupSourceDir: String
    private let backupDestinationPath: String
    private let sonDestinationPath: String
    private let dadDestinationPath: String
    private let dedDestinationPath: String
    private let fm = FileManager.default
    private let sourceIdentifier: String
    private var db = Database.shared
    private let backupDate: Date
    
    
    init(args: [String]) {
        backupSourceDir = fm.currentDirectoryPath
        backupDestinationPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path + "/" + BACKUP_FOLDER_NAME
        sourceIdentifier = backupSourceDir.sha256
        sonDestinationPath = backupDestinationPath + "/" + sourceIdentifier + "/" + BACKUP_SON_NAME
        dadDestinationPath = backupDestinationPath + "/" + sourceIdentifier + "/" + BACKUP_DAD_NAME
        dedDestinationPath = backupDestinationPath + "/" + sourceIdentifier + "/" + BACKUP_DED_NAME
        backupDate = Date()
    }

    private func checkExist(atPath: String) -> (Bool, Bool) {
        var isDir = ObjCBool(true)
        let exists = fm.fileExists(atPath: atPath, isDirectory: &isDir)
        return (exists, isDir.boolValue)
    }

    private func initFolder(path: String) throws {
        try fm.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    
    private func getItemsAtDir(dir: URL) throws {
        for i in try fm.contentsOfDirectory(atPath: dir.path) {
            let checkItemPath = dir.path + "/" + i
            switch checkExist(atPath: checkItemPath) {
                case(true, _):
                    let modifyDate = try fm.attributesOfItem(atPath: checkItemPath)[.modificationDate]
                    let name = fm.displayName(atPath: checkItemPath)
                    backupItemsList.append(Item(modificationDate: modifyDate as! Date, fullPath: checkItemPath, name: name))
            default: throw BackuperError.itemNotExists(path: i)
            }
        }
    }
    
    private func checkBackupFolders() throws {
        
        switch checkExist(atPath: sonDestinationPath) {
            case(false, _): try initFolder(path: sonDestinationPath)
            default: ()
        }
        
        switch checkExist(atPath: dadDestinationPath) {
            case(false, _): try initFolder(path: dadDestinationPath)
            default: ()
        }
        
        switch checkExist(atPath: dedDestinationPath) {
            case(false, _): try initFolder(path: dedDestinationPath)
            default: ()
        }
    }
    
    private func oldBackupsExists() throws -> Bool {
        return checkExist(atPath: backupDestinationPath + "/" + sourceIdentifier).0
    }
    
    private func firstBackup() throws {
        let currDate = Date()
        db.addNewItem(info: BackupInfo(hashName: sourceIdentifier, dedDate: currDate, dadDate: currDate, sonDate: currDate))
        for i in backupItemsList {
            try fm.copyItem(atPath: i.fullPath, toPath: dedDestinationPath + "/" + i.name)
        }
    }
    
    private func sonBackup() {
        
    }
    
    private func dadBackup() {
        
    }
    
    private func dedBackup() {
        
    }
    
    private func rotate() throws {
        let currDate = Int(backupDate.timeIntervalSince1970)
        let sonDate = db.getDate(name: sourceIdentifier, type: BackupInfo.BackupType.son)
        let dadDate = db.getDate(name: sourceIdentifier, type: BackupInfo.BackupType.dad)
        let dedDate = db.getDate(name: sourceIdentifier, type: BackupInfo.BackupType.ded)
        
        if currDate - dedDate! < DED_BACKUP_INTERVAL {
            if currDate - dadDate! < DAD_BACKUP_INTERVAL {
                if currDate - sonDate! >= SON_BACKUP_INTERVAL {
                    sonBackup()
                }
            } else { dadBackup() }
        } else { dedBackup() }
    }
    
    // MARK: Run
    func run() -> String {
        var error: String?
        do {
            try getItemsAtDir(dir: URL(string: backupSourceDir)!)
            if backupItemsList.isEmpty {
                throw BackuperError.emptyBackup
            }
            if try oldBackupsExists() {
                try rotate()
            } else {
                try initFolder(path: backupDestinationPath + "/" + sourceIdentifier)
                try checkBackupFolders()
                try firstBackup()
            }
            return "Success!"
            
        } catch BackuperError.itemAlreadyExists(let someItem) {
            error = "Item " + someItem + " already exist!!"
        } catch BackuperError.emptyBackup {
            error = "Nothing to backup!"
        } catch let someError {
            error = "\(someError.localizedDescription)"
        }
        return "Failed! \(error ?? "Unknown")"
    }
}


let mainFunc = Backuper(args: CommandLine.arguments)
print(mainFunc.run())
