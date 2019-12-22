import Foundation

let BACKUP_FOLDER_NAME = "macOSBackup"

struct Item {
    let modificationDate: Date
    let fullPath: String
    let name: String
}


enum BackuperError: Error {
    case itemNotExists(path: String)
    case itemAlreadyExists(path: String)
}


class Backuper {
    
    private var backupItemsList: [Item] = []
    private var backupSourceDir: String
    private var backupDestinationDir: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let fm = FileManager.default
    
    init(args: [String]) {
        backupSourceDir = fm.currentDirectoryPath
    }

    private func checkExist(atPath: String) -> (Bool, Bool) {
        var isDir = ObjCBool(true)
        let exists = fm.fileExists(atPath: atPath, isDirectory: &isDir)
        return (exists, isDir.boolValue)
    }

    private func initFolder(atPath: String) {

    }
    
    func run() -> String {
        do {
            try getItemsAtDir(dir: URL(string: backupSourceDir)!)
            let backupDestinationPath = backupDestinationDir.path + "/" + BACKUP_FOLDER_NAME;
            switch checkExist(atPath: backupDestinationPath) {
                case(false, _): initFolder(atPath: backupDestinationPath)
                default: ()
            }

            


        } catch BackuperError.itemAlreadyExists(let error) {
            print("Item " + error + " already exist!!")
        } catch let error {
            print("Error! -> \(error.localizedDescription)")
            exit(1)
        }
        return "Success!"
    }
    
    private func getItemsAtDir(dir: URL) throws {
        for i in try fm.contentsOfDirectory(atPath: dir.path) {
            let checkItemPath = dir.path + "/" + i
            switch checkExist(atPath: checkItemPath) {
                case(true, _):
                    let modifyDate = try fm.attributesOfItem(atPath: checkItemPath)[.modificationDate]
                    let name = fm.displayName(atPath: checkItemPath)
                    backupItemsList.append(Item(modificationDate: modifyDate as! Date, fullPath: checkItemPath, name: name))
                default: print("Item \(i) doesn't exists!")
            }
        }
    }
}

let mainFunc = Backuper(args: CommandLine.arguments)
print(mainFunc.run())
