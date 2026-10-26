import Darwin
import Foundation

/// File contents can change while a search window remains open. Do not key pictures by path alone.
nonisolated struct PreviewFileVersion: Equatable, Sendable {
    let path: String
    let modified: Double
    let size: Int64
    let fileNumber: UInt64

    init(_ url: URL) {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        path = resolved.path
        // Foundation's attributesOfItem also reads extended attributes (getxattr), which can block on
        // cloud/provider files. Cache identity needs only stat metadata, never quarantine or other xattrs.
        var metadata = stat()
        let readable = resolved.withUnsafeFileSystemRepresentation { pointer in
            pointer.map { Darwin.lstat($0, &metadata) == 0 } ?? false
        }
        modified = readable ? Double(metadata.st_mtimespec.tv_sec) + Double(metadata.st_mtimespec.tv_nsec) / 1e9 : 0
        size = readable ? metadata.st_size : -1
        fileNumber = readable ? UInt64(metadata.st_ino) : 0
    }

    var key: String { "\(path.utf8.count):\(path)|\(modified.bitPattern)|\(size)|\(fileNumber)" }
}

/// A cancelled native callback can still arrive. Only the current request may update its view.
final class PreviewRequestGate {
    private var generation: UInt64 = 0
    func begin() -> UInt64 { generation &+= 1; return generation }
    func accepts(_ token: UInt64) -> Bool { token == generation }
    func cancel() { generation &+= 1 }
}
