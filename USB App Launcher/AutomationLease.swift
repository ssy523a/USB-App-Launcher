import Darwin
import Foundation

/// One kernel-held advisory lock shared by both automation engines.
/// Never unlink/replace the lock file: doing so could create two lock domains.
nonisolated final class AutomationLease: @unchecked Sendable {
    private let descriptor: Int32

    private init(descriptor: Int32) { self.descriptor = descriptor }

    static func acquire() throws -> AutomationLease {
        guard let directory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first?.appendingPathComponent("USB App Launcher", isDirectory: true)
        else { throw LeaseError.unavailable }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("automation.lock").path
        let fd = open(path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw LeaseError.unavailable }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_uid == getuid(),
              (info.st_mode & S_IFMT) == S_IFREG, info.st_nlink == 1 else {
            close(fd)
            throw LeaseError.unavailable
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            close(fd)
            if code == EWOULDBLOCK { throw LeaseError.alreadyOwned }
            throw LeaseError.unavailable
        }
        return AutomationLease(descriptor: fd)
    }

    deinit {
        // Closing the sole descriptor releases the lock. O_CLOEXEC prevents
        // launched programs from inheriting this process's ownership.
        close(descriptor)
    }

    enum LeaseError: LocalizedError {
        case alreadyOwned, unavailable
        var errorDescription: String? {
            switch self {
            case .alreadyOwned:
                "Automation is inactive because another process owns it. Quit the other engine and restart this process."
            case .unavailable:
                "Automation is inactive because exclusive ownership could not be established."
            }
        }
    }
}
