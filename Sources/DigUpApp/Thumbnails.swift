import AppKit
import QuickLookThumbnailing

/// Result thumbnails from Quick Look (the system caches them across apps). Rows ask only when SwiftUI creates them,
/// so only visible rows cost anything, and the cache is dropped when the panel closes to keep the idle app small.
final class Thumbnails {
    static let shared = Thumbnails()
    private let cache = NSCache<NSString, NSImage>()
    private var inFlight = 0
    private var waiters: [() -> Void] = []

    typealias Generator = @Sendable (URL, CGFloat, CGFloat) async -> CGImage?
    private let generator: Generator
    private var generation = 0

    init(generator: @escaping Generator = Thumbnails.generate) {
        self.generator = generator
        cache.totalCostLimit = 32 << 20
    }

    func key(_ url: URL, side: CGFloat, scale: CGFloat = 1) -> NSString {
        "\(PreviewFileVersion(url).key)|\(side)|\(scale)" as NSString
    }

    func cached(_ url: URL, side: CGFloat, scale: CGFloat = 1) -> NSImage? {
        cache.object(forKey: key(url, side: side, scale: scale))
    }

    func load(_ url: URL, side: CGFloat, scale: CGFloat) async -> NSImage? {
        let version = PreviewFileVersion(url)
        let requestedKey = key(url, side: side, scale: scale)
        if let image = cache.object(forKey: requestedKey) { return image }
        let epoch = generation
        inFlight += 1
        defer {
            inFlight -= 1
            if inFlight == 0 { notifyIdle() }
        }
        guard let cgImage = await generator(url, side, scale), !Task.isCancelled,
              PreviewFileVersion(url) == version else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: CGFloat(cgImage.width) / scale,
                                                           height: CGFloat(cgImage.height) / scale))
        if epoch == generation {
            cache.setObject(image, forKey: requestedKey, cost: cgImage.bytesPerRow * cgImage.height)
        }
        return image
    }

    /// Nonisolated: Quick Look calls back on its own queue, and a closure made on the main actor would assert there.
    private nonisolated static func generate(_ url: URL, side: CGFloat, scale: CGFloat) async -> CGImage? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: side, height: side), scale: scale,
                                                   representationTypes: .thumbnail)
        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.cgImage)
            }
        }
    }

    func clear() {
        generation += 1
        cache.removeAllObjects()
    }

    /// Runs `body` once no thumbnail is loading (or after `timeout`), for debug snapshots.
    func whenIdle(timeout: TimeInterval, _ body: @escaping () -> Void) {
        var done = false
        let once = {
            guard !done else { return }
            done = true
            body()
        }
        if inFlight == 0 {
            // Give rows that just appeared a moment to ask for theirs.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return once() }
                if self.inFlight == 0 { once() } else { self.waiters.append(once) }
            }
        } else {
            waiters.append(once)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { once() }
    }

    private func notifyIdle() {
        let pending = waiters
        waiters = []
        pending.forEach { $0() }
    }
}
