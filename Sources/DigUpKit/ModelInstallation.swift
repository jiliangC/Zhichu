import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Verification and final installation are separate from network transport. Keep a verified partial on I/O failure.
public enum ModelInstallation {
    public enum Outcome: Sendable, Equatable {
        case installed
        case invalid(size: Int64)
    }

    public static func verifyAndInstall(_ partial: URL, file: ModelFiles.File, in folder: URL) throws -> Outcome {
        try perform(partial, file: file, in: folder, replace: atomicReplace)
    }

    static func perform(_ partial: URL, file: ModelFiles.File, in folder: URL,
                        replace: (URL, URL) throws -> Void) throws -> Outcome {
        let size = (try FileManager.default.attributesOfItem(atPath: partial.path)[.size] as? NSNumber)?.int64Value ?? -1
        guard size == file.bytes else { return .invalid(size: size) }
        guard try ModelFiles.sha256(of: partial) == file.sha256 else { return .invalid(size: size) }
        try replace(partial, folder.appendingPathComponent(file.name))
        return .installed
    }

    /// A rename within the model directory atomically replaces a regular file without first deleting the old one.
    private static func atomicReplace(_ source: URL, _ destination: URL) throws {
        #if canImport(Darwin)
        let status = source.withUnsafeFileSystemRepresentation { from in
            destination.withUnsafeFileSystemRepresentation { to in
                guard let from, let to else { errno = EINVAL; return Int32(-1) }
                return Darwin.rename(from, to)
            }
        }
        guard status == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        #else
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
        } else {
            try FileManager.default.moveItem(at: source, to: destination)
        }
        #endif
    }
}
