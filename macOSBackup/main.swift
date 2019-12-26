#!/usr/bin/swift
import Foundation


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
    private var sonSubFolders: [String] = []
    private var dadSubFolders: [String] = []
    private let remoteBackupDestination: String
    private let remoteBackupSource: String
    
    
    init(args: [String]) {
        backupSourceDir = fm.currentDirectoryPath
        backupDestinationPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path + "/" + BACKUP_FOLDER_NAME
        sourceIdentifier = backupSourceDir.sha256
        sonDestinationPath = backupDestinationPath + "/" + sourceIdentifier + "/" + BACKUP_SON_NAME
        dadDestinationPath = backupDestinationPath + "/" + sourceIdentifier + "/" + BACKUP_DAD_NAME
        dedDestinationPath = backupDestinationPath + "/" + sourceIdentifier + "/" + BACKUP_DED_NAME
        backupDate = Date()
        remoteBackupDestination = "st255@ohvost.ru:/home/st/st255/macOSBackup/\(sourceIdentifier)/"
        remoteBackupSource = "\(backupDestinationPath)/\(sourceIdentifier)/ded/"
        subfoldersInit()
    }
    
    private func subfoldersInit() {
        sonSubFolders.append(String(sonDestinationPath + "/1"))
        sonSubFolders.append(String(sonDestinationPath + "/2"))
        sonSubFolders.append(String(sonDestinationPath + "/3"))
        sonSubFolders.append(String(sonDestinationPath + "/4"))
        sonSubFolders.append(String(sonDestinationPath + "/5"))
        sonSubFolders.append(String(sonDestinationPath + "/6"))
        sonSubFolders.append(String(sonDestinationPath + "/7"))
        
        dadSubFolders.append(String(dadDestinationPath + "/1"))
        dadSubFolders.append(String(dadDestinationPath + "/2"))
        dadSubFolders.append(String(dadDestinationPath + "/3"))
        dadSubFolders.append(String(dadDestinationPath + "/4"))
    }

    private func sendDed() throws {
        let task = Process()
        let pipe = Pipe()
        let pipe_err = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
        task.arguments = ["-ru", "--delete", remoteBackupSource, remoteBackupDestination]
//        task.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
//        task.arguments = ["-r", remoteBackupSource, remoteBackupDestination]
        task.standardOutput = pipe
        task.standardError = pipe_err
        try task.run()

    }
    
    private func checkExist(atPath: String) -> (Bool, Bool) {
        var isDir = ObjCBool(true)
        let exists = fm.fileExists(atPath: atPath, isDirectory: &isDir)
        return (exists, isDir.boolValue)
    }

    private func initFolder(path: String) throws {
        try fm.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    
    private func getItemsAtDir(dir: String, _ add_param: String = "") throws {
        for i in try fm.contentsOfDirectory(atPath: dir) {
            let checkItemPath = dir + "/" + i
            switch checkExist(atPath: checkItemPath) {
                case(true, _):
                    let modifyDate = try fm.attributesOfItem(atPath: checkItemPath)[.modificationDate]
                    let name = add_param + fm.displayName(atPath: checkItemPath)
                    backupItemsList.append(Item(modificationDate: modifyDate as! Date, fullPath: checkItemPath, name: name))
            default: throw BackuperError.itemNotExists(path: i)
            }
        }
    }
    
    private func checkBackupFolders() throws {
        
        switch checkExist(atPath: sonDestinationPath) {
            case(false, _):
                try initFolder(path: sonDestinationPath)
                for i in sonSubFolders {
                        try initFolder(path: i)
                }
            default:
                try initFolder(path: sonDestinationPath)
                for i in sonSubFolders {
                        try initFolder(path: i)
                }
        }
        
        switch checkExist(atPath: dadDestinationPath) {
            case(false, _):
                try initFolder(path: dadDestinationPath)
                for i in dadSubFolders {
                        try initFolder(path: i)
                }
            default:
                try initFolder(path: dadDestinationPath)
                for i in dadSubFolders {
                        try initFolder(path: i)
                }
        }
        
        switch checkExist(atPath: dedDestinationPath) {
            case(false, _): try initFolder(path: dedDestinationPath)
            default: try initFolder(path: dedDestinationPath)
        }
    }
    
    private func oldBackupsExists() throws -> Bool {
        return checkExist(atPath: backupDestinationPath + "/" + sourceIdentifier).0
    }
    
    private func firstBackup() throws {
        db.addNewItem(info: BackupInfo(hashName: sourceIdentifier, dedDate: backupDate, dadDate: backupDate, sonDate: backupDate))
        for i in backupItemsList {
            try fm.copyItem(atPath: i.fullPath, toPath: dedDestinationPath + "/" + i.name)
        }
        do {
            try sendDed()
        } catch {
            print("Ded first backup doesn't send!")
        }
    }
    
    private func sonBackup() throws {
        var state = db.getState(name: sourceIdentifier, type: BackupInfo.BackupType.son)
        var updateList: [Item] = []
        let lastSonUpdateData = db.getDate(name: sourceIdentifier, type: BackupInfo.BackupType.son)
        for i in backupItemsList {
            if Int(i.modificationDate.timeIntervalSince1970) > lastSonUpdateData! {
                updateList.append(i)
            }
        }
        
        if state! == 8 {
            for j in sonSubFolders {
                try fm.removeItem(atPath: j)
            }
            try checkBackupFolders()
            try dadBackup()
            state = 1;
        }
        if updateList.count > 0 {
            for i in updateList {
                try fm.copyItem(atPath: i.fullPath, toPath: sonSubFolders[state! - 1] + "/" + i.name)
            }
            
            db.updateState(name: sourceIdentifier, type: BackupInfo.BackupType.son, state: state! + 1)
            db.updateDate(name: sourceIdentifier, date: backupDate, type: BackupInfo.BackupType.son)
        }
    }
    
    private func dadBackup() throws {
        var state = db.getState(name: sourceIdentifier, type: BackupInfo.BackupType.dad)
        if state! == 5 {
            for j in dadSubFolders {
                try fm.removeItem(atPath: j)
            }
            try checkBackupFolders()
            try dedBackup()
            state = 1;
        }
        
        for i in backupItemsList {
            try fm.copyItem(atPath: i.fullPath, toPath: dadSubFolders[state! - 1]  + "/" + i.name)
        }
        db.updateState(name: sourceIdentifier, type: BackupInfo.BackupType.dad, state: state! + 1)
        db.updateDate(name: sourceIdentifier, date: backupDate, type: BackupInfo.BackupType.dad)
    }
    
    private func dedBackup() throws {
        try fm.removeItem(atPath: dedDestinationPath)
        try checkBackupFolders()
        for i in backupItemsList {
            try fm.copyItem(atPath: i.fullPath, toPath: dedDestinationPath + "/" + i.name)
        }
        db.updateDate(name: sourceIdentifier, date: backupDate, type: BackupInfo.BackupType.dad)
        db.updateDate(name: sourceIdentifier, date: backupDate, type: BackupInfo.BackupType.ded)
        db.updateDate(name: sourceIdentifier, date: backupDate, type: BackupInfo.BackupType.son)
        do {
            try sendDed()
        } catch {
            print("Ded backup doesn't send!")
        }
    }
    
    private func rotate() throws {
        let currDate = Int(backupDate.timeIntervalSince1970)
        let sonDate = db.getDate(name: sourceIdentifier, type: BackupInfo.BackupType.son)
        let dadDate = db.getDate(name: sourceIdentifier, type: BackupInfo.BackupType.dad)
        let dedDate = db.getDate(name: sourceIdentifier, type: BackupInfo.BackupType.ded)
        
//        if currDate - dedDate! < DED_BACKUP_INTERVAL {
//            if currDate - dadDate! < DAD_BACKUP_INTERVAL {
//                if currDate - sonDate! >= SON_BACKUP_INTERVAL {
//                    try sonBackup()
//                }
//            } else { try dadBackup() }
//        } else { try dedBackup() }
        try sonBackup()
    }
    
    // MARK: Run
    func run() -> String {
        var error: String?
        do {
            try getItemsAtDir(dir: backupSourceDir)
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
