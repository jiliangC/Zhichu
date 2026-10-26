import AppKit
import Foundation
import Testing
@testable import DigUpKit
@testable import ZhichuApp

private nonisolated func picture() -> CGImage {
    let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    return context.makeImage()!
}

private actor ImageSource {
    var calls = 0
    private var pending: CheckedContinuation<CGImage?, Never>?
    private var ready: CheckedContinuation<Void, Never>?
    func immediate() -> CGImage { calls += 1; return picture() }
    func delayed() async -> CGImage? {
        calls += 1
        return await withCheckedContinuation { continuation in
            pending = continuation
            ready?.resume(); ready = nil
        }
    }
    func waitForRequest() async {
        if pending != nil { return }
        await withCheckedContinuation { ready = $0 }
    }
    func finish() { pending?.resume(returning: picture()); pending = nil }
}

@Suite @MainActor final class PreviewLoadingTests {
    let folder: URL
    let url: URL
    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("ZhichuPreviewTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("sample.png")
        try Data([1]).write(to: url)
    }
    deinit { try? FileManager.default.removeItem(at: folder) }
    func changeFile() throws {
        try Data([2, 3]).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(2)], ofItemAtPath: url.path)
    }
    func row(modified: Double = 1, segment: Int64 = 1) -> ResultRow {
        ResultRow(SearchHit(path: url.path, kind: .image, score: 1, z: nil, cosine: nil, keywordRank: nil,
                            segment: .image, segmentID: segment, loc: nil, locEnd: nil, excerpt: nil,
                            modified: modified, size: 1, info: [:]))
    }

    @Test func changedFilesAndDisplayScalesGetNewThumbnails() async throws {
        let source = ImageSource()
        let cache = Thumbnails { _, _, _ in await source.immediate() }
        let first = await cache.load(url, side: 36, scale: 1)
        let repeated = await cache.load(url, side: 36, scale: 1)
        #expect(first != nil && first === repeated)
        #expect(await source.calls == 1)
        try changeFile()
        #expect(cache.cached(url, side: 36, scale: 1) == nil)
        let changed = await cache.load(url, side: 36, scale: 1)
        #expect(changed != nil && changed !== first)
        _ = await cache.load(url, side: 36, scale: 2)
        #expect(await source.calls == 3)
    }

    @Test func fileChangingDuringLoadRejectsOutdatedPicture() async throws {
        let source = ImageSource()
        let cache = Thumbnails { _, _, _ in await source.delayed() }
        let task = Task { await cache.load(url, side: 36, scale: 1) }
        await source.waitForRequest()
        try changeFile()
        await source.finish()
        #expect(await task.value == nil)
        #expect(cache.cached(url, side: 36, scale: 1) == nil)
    }

    @Test func cancelledLoadsCannotPopulateCache() async {
        let source = ImageSource()
        let cache = Thumbnails { _, _, _ in await source.delayed() }
        let task = Task { await cache.load(url, side: 36, scale: 1) }
        await source.waitForRequest()
        task.cancel()
        await source.finish()
        #expect(await task.value == nil)
        #expect(cache.cached(url, side: 36, scale: 1) == nil)
    }

    @Test func clearingCacheWhileLoadingPreventsLateRefill() async {
        let source = ImageSource()
        let cache = Thumbnails { _, _, _ in await source.delayed() }
        let task = Task { await cache.load(url, side: 36, scale: 1) }
        await source.waitForRequest()
        cache.clear()
        await source.finish()
        #expect(await task.value != nil)
        #expect(cache.cached(url, side: 36, scale: 1) == nil)
    }

    @Test func slowPreviousSelectionCannotOverwriteNewerPreview() async throws {
        let source = ImageSource()
        let other = folder.appendingPathComponent("other.png")
        try Data([4]).write(to: other)
        let firstURL = url
        let cache = Thumbnails { url, _, _ in
            if url == firstURL { return await source.delayed() }
            return picture()
        }
        let gate = PreviewRequestGate()
        var displayed: NSImage?
        func select(_ url: URL) async {
            let token = gate.begin()
            let candidate = await cache.load(url, side: 36, scale: 1)
            guard !Task.isCancelled, gate.accepts(token) else { return }
            displayed = candidate
        }
        let old = Task { await select(firstURL) }
        await source.waitForRequest()
        await select(other)
        let newest = displayed
        #expect(newest != nil)
        await source.finish()
        await old.value
        #expect(displayed === newest)
    }

    @Test func requestGateRejectsOldSelectionAndDisappearedView() {
        let gate = PreviewRequestGate()
        let first = gate.begin()
        let second = gate.begin()
        #expect(!gate.accepts(first) && gate.accepts(second))
        gate.cancel()
        #expect(!gate.accepts(second))
    }

    @Test func previewKeysIncludeFileRevisionSegmentAndScale() throws {
        let previews = Previews()
        #expect(row().previewKey != row(modified: 2).previewKey)
        #expect(row().previewKey != row(segment: 2).previewKey)
        let before = previews.key(row(), 100, scale: 1)
        #expect(before != previews.key(row(), 100, scale: 2))
        try changeFile()
        #expect(before != previews.key(row(), 100, scale: 1))
    }
}
