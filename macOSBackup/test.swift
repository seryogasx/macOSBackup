import Foundation
let task = Process()
let sourceIdentifier = "15352de857c794ca884170ce3aa17bdf17499ea39a94ebbac7da62a0d8f479b7"
let remoteBackupSource = "/Users/seryogas/Documents/macOSBackup/\(sourceIdentifier)/ded/"
let remoteBackupDestination = "st255@ohvost.ru:/home/st/st255/macOSBackup/\(sourceIdentifier)/"
task.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
task.arguments = ["-ru", "--delete", remoteBackupSource, remoteBackupDestination]
do {
    try task.run()
} catch {
    print("!")
}
