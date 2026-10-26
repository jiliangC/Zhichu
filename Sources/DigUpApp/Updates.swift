import AppKit
import Sparkle

/// In-app updates, with Sparkle. Once a day 知处 reads its appcast (`SUFeedURL` in Info.plist); a newer version is
/// downloaded, checked against the EdDSA key in Info.plist (`SUPublicEDKey`) and Apple's signature, put in place of this
/// copy and reopened, after one click. Finder can't replace a running app, and 知处 runs most of the time.
///
/// 知处 lives in the menu bar, so an update the daily check finds doesn't pop up over whatever you're doing (Sparkle's
/// "gentle reminders"): it waits in the menu ("Update to 知处 0.6.1…"), as a dot on the menubar mark, and in the
/// window's status bar, until you open it. Checks you ask for show Sparkle's window at once.
final class Updates: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private let model: AppModel
    private var controller: SPUStandardUpdaterController?
    private var observations: [NSKeyValueObservation] = []
    private var started = false
    /// Only enable updates when the application has its own HTTPS feed and signing key.
    var isConfigured: Bool { controller != nil }
    /// Sparkle's window closed: the Dock icon goes unless one of 知处's windows is open.
    var onSessionEnded: () -> Void = {}

    init(model: AppModel) {
        self.model = model
        super.init()
        if let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
           URL(string: feed)?.scheme == "https",
           let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
           Data(base64Encoded: key)?.count == 32 {
            controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
            if let updater = controller?.updater {
                observations = [
                    updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, _ in
                        Task { @MainActor [weak self] in self?.refreshState() }
                    },
                    updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] _, _ in
                        Task { @MainActor [weak self] in self?.refreshState() }
                    }
                ]
            }
        }
    }

    /// Dev and test runs (their own defaults suite) don't check: Sparkle keeps its state in the app's real defaults.
    /// `-debugUpdates YES` lets one check anyway.
    func start() {
        guard let controller, !started else { return }
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: "defaultsSuite") == nil || defaults.bool(forKey: "debugUpdates") else { return }
        do {
            try controller.updater.start()
            started = true
            refreshState()
        } catch {
            model.updateCheckStatus = "更新服务启动失败，请稍后重新打开知处。"
            log("updates: failed to start: \(error)")
            return
        }
        log("updates: \(controller.updater.automaticallyChecksForUpdates ? "checking daily" : "automatic checks off") "
            + "at \(controller.updater.feedURL?.absoluteString ?? "no feed")")
    }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var canCheck: Bool { controller?.updater.canCheckForUpdates ?? false }

    private func refreshState() {
        model.canCheckForUpdates = canCheck
        model.lastUpdateCheck = controller?.updater.lastUpdateCheckDate
    }

    /// "检查更新" and the waiting update's menu item: Sparkle's window, in front.
    func checkNow() {
        guard let controller else {
            let alert = NSAlert()
            alert.messageText = "此构建未配置更新服务"
            alert.informativeText = "请从 https://github.com/jiliangC/Zhichu/releases 下载知处的新版本。"
            alert.addButton(withTitle: "好")
            alert.runModal()
            return
        }
        guard canCheck else { return }
        model.updateCheckStatus = "正在检查更新…"
        NSApp.setActivationPolicy(.regular)
        bringAppToFront()
        controller.checkForUpdates(nil)
    }

    /// A check in the background, as the daily one (for `-debugUpdateCheck`).
    func checkInBackground() {
        controller?.updater.checkForUpdatesInBackground()
    }

    // MARK: Gentle reminders

    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// An update the daily check found waits for you to open it.
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                             andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        if handleShowingUpdate {
            // Sparkle's window comes up: like 知处's own windows, with the Dock icon while it's open.
            NSApp.setActivationPolicy(.regular)
            bringAppToFront()
        } else {
            model.updateAvailable = update.displayVersionString
            log("updates: \(update.displayVersionString) is available; waiting in the menu")
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        model.updateAvailable = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        model.updateAvailable = nil
        onSessionEnded()
    }

    // MARK: What happened (logged)

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        model.updateCheckStatus = "发现新版本 \(item.displayVersionString)"
        log("updates: found \(item.displayVersionString) (\(item.versionString))")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        model.updateCheckStatus = "未发现适用于此 Mac 的新版本"
        log("updates: up to date")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        let nsError = error as NSError
        if nsError.domain != SUSparkleErrorDomain || nsError.code != SUError.noUpdateError.rawValue {
            model.updateCheckStatus = "检查或更新未完成：\(error.localizedDescription)"
        }
        log("updates: \(error.localizedDescription)")
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if model.updateCheckStatus == "正在检查更新…" {
            model.updateCheckStatus = "检查已结束"
        }
        refreshState()
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        model.updateCheckStatus = "正在安装知处 \(item.displayVersionString)…"
        log("updates: installing \(item.displayVersionString)")
    }
}
