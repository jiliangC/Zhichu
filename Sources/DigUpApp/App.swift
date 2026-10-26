import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var app: AppController?

    static func main() {
        signal(SIGPIPE, SIG_IGN)   // a helper that just exited must surface as a write error, not kill the app
        // DIGUP_WORKER_DIR runs another worker (the Python reference, for evals) in place of the bundled model. Only
        // dev runs take it: anywhere else it would have 知处, and its helpers, start whatever that folder holds.
        if UserDefaults.standard.string(forKey: "defaultsSuite") == nil { unsetenv("DIGUP_WORKER_DIR") }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isAlreadyRunning() {
            NSApp.terminate(nil)
            return
        }
        // For testing both themes: `-forceAppearance dark` (or light).
        switch UserDefaults.standard.string(forKey: "forceAppearance") {
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        default: break
        }

        let settings = AppSettings.load()
        AppLog.shared.open(in: settings.indexDirectory)
        log("launch pid \(getpid()): roots \(settings.roots.map { tildePath($0.path) }) · "
            + "index \(tildePath(settings.indexDirectory.path)) · models \(tildePath(settings.modelsDirectory.path))")
        let (atLogin, why) = Launch.atLogin()   // while the open-application event is still the current one
        let showWindow = !atLogin && !DebugHooks.drivesUI
        log("launch: \(atLogin ? "at login" : "opened by hand") (\(why))\(showWindow ? ", showing the window" : "")")

        let app = AppController(settings: settings)
        self.app = app
        NSApp.mainMenu = Self.makeMainMenu(app)
        app.start(showWindow: showWindow)
        DebugHooks.run(app)
    }

    /// Opening the app again (from Finder or Spotlight) while it runs: show its window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { app?.showSearchWindow() }
        return true
    }

    /// Another copy is running (a second copy of the app, launched from elsewhere). Dev and test runs, which keep their
    /// own settings, index and models (`-defaultsSuite`), run alongside an installed 知处 that's in use.
    private func isAlreadyRunning() -> Bool {
        guard UserDefaults.standard.string(forKey: "defaultsSuite") == nil,
              let id = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains { $0 != NSRunningApplication.current }
    }

    /// The menu bar while a window is open (the Dock icon shows then). It also gives text fields ⌘C/⌘V/⌘A/⌘Z.
    private static func makeMainMenu(_ app: AppController) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于知处", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(ActionMenuItem("检查更新", isEnabled: { [weak app] in app?.updates.canCheck == true }) { [weak app] in app?.updates.checkNow() })
        appMenu.addItem(.separator())
        appMenu.addItem(ActionMenuItem("设置", key: ",") { [weak app] in app?.showSettings() })
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏知处", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出知处", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(ActionMenuItem("新建搜索", key: "n") { [weak app] in app?.showSearchWindow(query: "") })
        fileMenu.addItem(withTitle: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "关闭", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        for submenu in [appMenu, fileMenu, editMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        return mainMenu
    }
}

/// How 知处 was launched. At login (its login item) it stays in the menu bar; opened by hand (Finder, Spotlight,
/// Launchpad, after an update) it shows its window, so opening it never looks like nothing happened.
enum Launch {
    /// Whether this is the launch at login, and what says so. Call it while the app finishes launching: the
    /// open-application event is still the current one then.
    static func atLogin() -> (Bool, String) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        if event?.eventID == AEEventID(kAEOpenApplication),
           event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem) {
            return (true, "the login item")
        }
        // In case macOS doesn't mark the login item's launch: within two minutes of logging in counts as at login.
        guard let login = consoleLogin() else { return (false, "no login time") }
        let since = Date().timeIntervalSince(login)
        return (since < 120, "logged in \(Int(since)) s ago")
    }

    /// When this user logged in at the Mac (what `who` shows for the console).
    private static func consoleLogin() -> Date? {
        setutxent()
        defer { endutxent() }
        var latest: Date?
        while let entry = getutxent()?.pointee {
            guard Int32(entry.ut_type) == USER_PROCESS, text(entry.ut_line) == "console",
                  text(entry.ut_user) == NSUserName() else { continue }
            let time = Date(timeIntervalSince1970: TimeInterval(entry.ut_tv.tv_sec))
            if latest.map({ time > $0 }) ?? true { latest = time }
        }
        return latest
    }

    /// A fixed-size C string field of a utmpx entry.
    private static func text<Field>(_ field: Field) -> String {
        withUnsafeBytes(of: field) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
}

/// Brings 知处 to the front. Plain `NSApp.activate()` is only a request that macOS may decline while another
/// app is in use; the panel needs real activation so App Nap doesn't slow search down.
func bringAppToFront() {
    (NSApp as any ForcedActivation).activate(ignoringOtherApps: true)
}

/// Calls the older activation API without a deprecation warning.
private protocol ForcedActivation {
    func activate(ignoringOtherApps: Bool)
}

extension NSApplication: ForcedActivation {}
