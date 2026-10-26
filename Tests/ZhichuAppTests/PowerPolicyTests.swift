import Foundation
import Testing
@testable import DigUpKit
@testable import ZhichuApp

@Suite @MainActor struct PowerPolicyTests {
    @Test func powerTransitionsAndSettingChangesNotifyTheHardGate() {
        var onAC = true
        var updates: [String?] = []
        let policy = PowerPolicy(indexOnBattery: false, hasACPower: { onAC }) { _, update in updates.append(update) }
        #expect(policy.updateBlocker == nil)
        onAC = false; policy.reevaluate()
        #expect(policy.updateBlocker == "正在使用电池，接通电源后继续")
        let count = updates.count
        policy.reevaluate()
        #expect(updates.count == count, "Unchanged state must not repeatedly cancel/restart work")
        onAC = true; policy.reevaluate()
        #expect(policy.updateBlocker == nil)
        onAC = false; policy.reevaluate()
        policy.setIndexOnBattery(true)
        #expect(policy.updateBlocker == nil)
        policy.setIndexOnBattery(false)
        #expect(policy.updateBlocker != nil)
        #expect(updates.count == count + 4)
    }

    @Test func waitingForPowerTakesPrecedenceOverInFlightUIAndDoesNotChangeSearchEligibility() {
        var settings = AppSettings.load()
        settings.roots = [URL(fileURLWithPath: "/Test")]; settings.mail.enabled = true
        settings.codeRoots = [URL(fileURLWithPath: "/Code")]
        let model = AppModel(settings: settings, download: ModelDownload(folder: URL(fileURLWithPath: "/no-test-models")))
        model.status.activity = .indexing(done: 1, total: 10)
        model.status.code.indexing = .init(done: 1, total: 10)
        model.status.powerBlocker = "正在使用电池，接通电源后继续"
        #expect(model.statusLine == "索引更新已暂停 · 正在使用电池，接通电源后继续")
        #expect(model.sourceStatusLine(.mail).contains("接通电源后继续"))
        #expect(model.sourceStatusLine(.folders).contains("接通电源后继续"))
        #expect(model.codeStatusLine.contains("接通电源后继续"))
        #expect(model.activityBadge == "等待接通电源")
        #expect(model.progress == nil)
        #expect(!model.status.paused, "Power waiting must not overwrite manual pause")
        #expect(model.hasFolders && model.hasCode)
        model.status.paused = true
        model.status.powerBlocker = nil
        #expect(model.status.paused, "Returning to AC must preserve a user's manual pause")
    }

    @Test func batteryGatePreventsInitialAndNewFileIndexingAndRetainsManualPause() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PowerGate-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let files = root.appendingPathComponent("files")
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        try Data("先前的资料".utf8).write(to: files.appendingPathComponent("before.txt"))
        var settings = AppSettings.load()
        settings.roots = [files]; settings.excludedFolders = []; settings.excludedTypes = []
        settings.codeRoots = []; settings.mail.enabled = false
        settings.indexDirectory = root.appendingPathComponent("index")
        settings.modelsDirectory = root.appendingPathComponent("models")
        var latest = EngineStatus()
        let engine = Engine(settings: settings, backfillBlocker: nil, heldUntil: nil,
                            powerBlocker: "正在使用电池，接通电源后继续") { latest = $0 }
        engine.start()
        for _ in 0..<50 {
            if latest.activity == .idle { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(latest.activity == .idle)
        #expect(latest.powerBlocker != nil)
        try Data("新增的资料".utf8).write(to: files.appendingPathComponent("after.txt"))
        try await Task.sleep(for: .seconds(1.5))
        #expect(latest.activity == .idle)
        let db = try Database(path: settings.indexDirectory.appendingPathComponent(IndexStore.mainFile).path, readOnly: true)
        var count: Int64 = -1
        try db.query("SELECT count(*) FROM files") { count = $0.int(0) }
        #expect(count == 0, "No initial or incremental crawl may run while battery-gated")
        #expect(!FileManager.default.fileExists(atPath: settings.indexDirectory.appendingPathComponent("indexer.log").path))
        engine.setPaused(true)
        engine.setPowerBlocker(nil)
        try await Task.sleep(for: .milliseconds(300))
        #expect(latest.paused)
        #expect(latest.powerBlocker == nil)
        #expect(!FileManager.default.fileExists(atPath: settings.indexDirectory.appendingPathComponent("indexer.log").path))
    }

    @Test func manualMailRefreshCannotBypassBatteryGate() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MailPowerGate-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        var settings = AppSettings.load()
        settings.roots = []; settings.codeRoots = []; settings.mail.enabled = true
        settings.indexDirectory = root.appendingPathComponent("index")
        settings.modelsDirectory = root.appendingPathComponent("models")
        settings.mailRoot = root.appendingPathComponent("must-not-be-read")
        let app = AppController(settings: settings)
        let mail = MailController(app: app)
        mail.setUpdateBlocker("正在使用电池，接通电源后继续")
        mail.refresh()
        try await Task.sleep(for: .milliseconds(100))
        #expect(!mail.syncing)
        #expect(mail.problem == nil, "The missing source must not be visited and produce a read error")
        #expect(mail.notice.contains("接通电源后继续"))
        #expect(!FileManager.default.fileExists(atPath: settings.mailCache.path))
    }
}
