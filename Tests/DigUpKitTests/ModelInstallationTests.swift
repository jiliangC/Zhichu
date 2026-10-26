import Foundation
import Testing
@testable import DigUpKit

@Suite final class ModelInstallationTests {
    let folder: URL
    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("ZhichuModelInstall-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: folder) }

    func fixture() throws -> (URL, ModelFiles.File) {
        let partial = folder.appendingPathComponent("model.partial")
        try Data("verified-model".utf8).write(to: partial)
        return (partial, ModelFiles.File(name: "model.gguf", bytes: 14, sha256: try ModelFiles.sha256(of: partial)))
    }

    @Test func verifiedFileAtomicallyReplacesOldModel() throws {
        let (partial, file) = try fixture()
        let destination = folder.appendingPathComponent(file.name)
        try Data("old".utf8).write(to: destination)
        #expect(try ModelInstallation.verifyAndInstall(partial, file: file, in: folder) == .installed)
        #expect(try Data(contentsOf: destination) == Data("verified-model".utf8))
        #expect(!FileManager.default.fileExists(atPath: partial.path))
    }

    @Test func failedInstallationKeepsBothOldModelAndVerifiedPartial() throws {
        struct NoWrite: Error {}
        let (partial, file) = try fixture()
        let destination = folder.appendingPathComponent(file.name)
        let old = Data("known-good-old".utf8)
        try old.write(to: destination)
        #expect(throws: NoWrite.self) {
            try ModelInstallation.perform(partial, file: file, in: folder) { _, _ in throw NoWrite() }
        }
        #expect(try Data(contentsOf: destination) == old)
        #expect(try ModelFiles.sha256(of: partial) == file.sha256)
        #expect(try ModelInstallation.verifyAndInstall(partial, file: file, in: folder) == .installed)
    }

    @Test func actualRenameFailureDoesNotDiscardTheDownload() throws {
        let (partial, file) = try fixture()
        let destination = folder.appendingPathComponent(file.name)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        try Data("keep".utf8).write(to: destination.appendingPathComponent("keep.txt"))
        #expect(throws: (any Error).self) { try ModelInstallation.verifyAndInstall(partial, file: file, in: folder) }
        #expect(try ModelFiles.sha256(of: partial) == file.sha256)
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("keep.txt").path))
    }

    @Test func invalidHashNeverReplacesTheInstalledFile() throws {
        let (partial, file) = try fixture()
        let destination = folder.appendingPathComponent(file.name)
        let old = Data("old-model".utf8)
        try old.write(to: destination)
        try Data(repeating: 0, count: Int(file.bytes)).write(to: partial)
        #expect(try ModelInstallation.verifyAndInstall(partial, file: file, in: folder) == .invalid(size: file.bytes))
        #expect(try Data(contentsOf: destination) == old)
    }
}
