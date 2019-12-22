import Foundation
//import CommonCrypto
import CryptoKit


extension String {
    var sha256: String {
        String(SHA256.hash(data: Data(self.utf8)).description.suffix(64))
    }
}


// MARK: Backuper
class Backuper {
    
    let BACKUP_FOLDER_NAME = "macOSBackup"
    let BACKUP_SON_NAME = "son"
    let BACKUP_DAD_NAME = "dad"
    let BACKUP_DED_NAME = "ded"
    private var backupItemsList: [Item] = []
    private let backupSourceDir: String
    private let backupDestinationPath: String
    private let sonDestinationPath: String
    private let dadDestinationPath: String
    private let dedDestinationPath: String
    private let fm = FileManager.default
    private let sourceIdentifier: String
    
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
    
    init(args: [String]) {
        backupSourceDir = fm.currentDirectoryPath
        backupDestinationPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path + "/" + BACKUP_FOLDER_NAME
        sourceIdentifier = backupSourceDir.sha256
        sonDestinationPath = backupDestinationPath + "/" + sourceIdentifier + "/" + BACKUP_SON_NAME
        dadDestinationPath = backupDestinationPath + "/" + sourceIdentifier + "/" + BACKUP_DAD_NAME
        dedDestinationPath = backupDestinationPath + "/" + sourceIdentifier + "/" + BACKUP_DED_NAME
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
        
    }
    
    private func rotate() throws {
        
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
