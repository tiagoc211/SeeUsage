import Foundation
import Darwin

public enum SharedFileLock {
    public static func withExclusiveLock<T>(for fileURL: URL, _ operation: () throws -> T) rethrows -> T {
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let lockURL = fileURL.appendingPathExtension("lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return try operation() }
        guard flock(descriptor, LOCK_EX) == 0 else {
            close(descriptor)
            return try operation()
        }
        defer {
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }
        return try operation()
    }
}
