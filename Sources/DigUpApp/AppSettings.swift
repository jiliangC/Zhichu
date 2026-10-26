import DigUpKit
import Foundation

/// What to index, where the index and the model live, and the hotkey.
///
/// Saved in the app's defaults domain (app.zhichu.mac). Launch arguments override any of it without being
/// saved, which is how tests point the app at the testbed and never at real folders:
///
///     知处.app/Contents/MacOS/知处 -roots ~/DigUpTestbed/real -indexDir <repo>/.dev/app-index \
///         -modelsDir <repo>/.dev/models -defaultsSuite app.zhichu.mac.dev
///
/// `-roots` takes one folder, several joined with ":", or a plist array. `-defaultsSuite` keeps what the app saves
/// (onboarding's folders, a new hotkey) out of the real settings. With no roots the app indexes nothing and opens
/// onboarding: a fresh install never starts reading someone's home folder on its own.
nonisolated struct AppSettings: Sendable {
    var roots: [URL]
    /// Folders inside the roots that are never indexed.
    var excludedFolders: [URL]
    /// File extensions that are never indexed ("heic", "txt"), on top of what 知处 never reads anyway.
    var excludedTypes: [String]
    var indexDirectory: URL
    /// Where the model files are downloaded to and loaded from (the helpers get it as DIGUP_MODELS).
    var modelsDirectory: URL
    var hotkey: String
    /// Off by default: all indexing and Mail synchronization wait for AC. Search still works on battery.
    /// Low Power Mode or a hot Mac also make the backfill wait when indexing is allowed.
    var indexOnBattery: Bool
    /// "仅在指定时段建立索引": off by default. Outside the hours no helper runs (no crawl, no new files, no
    /// backfill); search works all day. The hours are kept while it's off.
    var indexHoursOn: Bool
    var indexHours: IndexHours
    /// The query encoder (~0.25 GB) exits after this long without a query; the next panel open starts it again.
    var encoderIdleSeconds: Double
    /// Onboarding was finished (or closed after choosing folders); it doesn't open by itself again.
    var onboarded: Bool
    /// Code search: the folders whose code goes into the code index (none: code search is off), and the folders
    /// skipped in them (`FolderSelection`'s rule, as for `roots`). Searched with "code:" only.
    var codeRoots: [URL]
    var codeExcluded: [URL]
    /// The bundle id of the editor code results open in ("" for each file's default app); nil until one is chosen
    /// (`CodeEditor.chosen`).
    var codeEditor: String?
    /// The code index catches up once the code folders have been quiet this long (`-codeQuietSeconds`, default 60).
    var codeQuietSeconds: Double
    var mail = MailConfiguration()
    var mailRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mail")
    var mailCache: URL { indexDirectory.appendingPathComponent("MailSources") }

    static let supportDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Zhichu")
    static let defaultIndexDirectory = supportDirectory.appendingPathComponent("index.noindex")
    static let defaultHotkey = "cmd+shift+space"

    /// The battery switch, in onboarding and Settings.
    static let batteryTitle = "仅接通电源时更新索引"
    static let batteryDetail = "使用电池时暂停文件、邮件和代码的索引更新及邮件同步；接通电源后继续，已有内容仍可搜索。"

    /// Where settings are saved. Reads see launch arguments first either way. (UserDefaults is thread-safe.)
    nonisolated(unsafe) static let defaults: UserDefaults = {
        guard let suite = UserDefaults.standard.string(forKey: "defaultsSuite"), !suite.isEmpty,
              let defaults = UserDefaults(suiteName: suite) else { return .standard }
        return defaults
    }()

    static func load() -> AppSettings {
        let defaults = Self.defaults
        var settings = AppSettings(
            roots: folders(defaults, "roots"),
            excludedFolders: folders(defaults, "excludedFolders"),
            excludedTypes: (defaults.stringArray(forKey: "excludedTypes")
                ?? defaults.string(forKey: "excludedTypes").map { [$0] } ?? [])
                .flatMap { IndexOptions.extensions($0) }.sorted(),
            indexDirectory: defaults.string(forKey: "indexDir").map(folderURL) ?? defaultIndexDirectory,
            modelsDirectory: defaults.string(forKey: "modelsDir").map(folderURL) ?? ModelFiles.installed,
            hotkey: defaults.string(forKey: "hotkey") ?? defaultHotkey,
            indexOnBattery: defaults.bool(forKey: "indexOnBattery"),
            indexHoursOn: defaults.bool(forKey: "indexHoursOn"),
            indexHours: IndexHours(
                start: defaults.object(forKey: "indexHoursFrom") == nil ? IndexHours.night.start
                    : defaults.integer(forKey: "indexHoursFrom"),
                end: defaults.object(forKey: "indexHoursTo") == nil ? IndexHours.night.end
                    : defaults.integer(forKey: "indexHoursTo")),
            encoderIdleSeconds: defaults.object(forKey: "encoderIdleSeconds") == nil
                ? 600 : max(1, defaults.double(forKey: "encoderIdleSeconds")),
            onboarded: defaults.bool(forKey: "onboarded"),
            codeRoots: folders(defaults, "codeRoots"),
            codeExcluded: folders(defaults, "codeExcludedFolders"),
            codeEditor: defaults.string(forKey: "codeEditor"),
            codeQuietSeconds: defaults.object(forKey: "codeQuietSeconds") == nil
                ? 60 : max(1, defaults.double(forKey: "codeQuietSeconds")))
        if let data = defaults.data(forKey: "mailConfiguration"), let value = try? JSONDecoder().decode(MailConfiguration.self, from: data) { settings.mail = value }
        if defaults.object(forKey: "mailEnabled") != nil { settings.mail.enabled = defaults.bool(forKey: "mailEnabled") }
        if let path = defaults.string(forKey: "mailRoot") { settings.mailRoot = folderURL(path) }
        return settings
    }

    /// A list of folders: a plist array, or paths joined with ":" (the form launch arguments use).
    private static func folders(_ defaults: UserDefaults, _ key: String) -> [URL] {
        let paths: [String]
        if let list = defaults.stringArray(forKey: key) {
            paths = list
        } else if let joined = defaults.string(forKey: key) {
            paths = joined.split(separator: ":").map(String.init)
        } else {
            paths = []
        }
        var seen = Set<String>()
        return paths.filter { !$0.isEmpty }.map(folderURL).filter { seen.insert($0.path).inserted }
    }

    static func save(roots: [URL]) {
        defaults.set(roots.map(\.path), forKey: "roots")
    }

    static func save(excludedFolders: [URL]) {
        defaults.set(excludedFolders.map(\.path), forKey: "excludedFolders")
    }

    static func save(excludedTypes: [String]) {
        defaults.set(excludedTypes, forKey: "excludedTypes")
    }

    static func save(mail: MailConfiguration) {
        if let data = try? JSONEncoder().encode(mail) { defaults.set(data, forKey: "mailConfiguration") }
    }

    static func save(hotkey: String) {
        defaults.set(hotkey, forKey: "hotkey")
    }

    static func save(indexOnBattery: Bool) {
        defaults.set(indexOnBattery, forKey: "indexOnBattery")
    }

    static func save(indexHoursOn: Bool, hours: IndexHours) {
        defaults.set(indexHoursOn, forKey: "indexHoursOn")
        defaults.set(hours.start, forKey: "indexHoursFrom")
        defaults.set(hours.end, forKey: "indexHoursTo")
    }

    static func saveOnboarded() {
        defaults.set(true, forKey: "onboarded")
    }

    static func save(codeRoots: [URL], excluded: [URL]) {
        defaults.set(codeRoots.map(\.path), forKey: "codeRoots")
        defaults.set(excluded.map(\.path), forKey: "codeExcludedFolders")
    }

    static func save(codeEditor: String) {
        defaults.set(codeEditor, forKey: "codeEditor")
    }

    /// Expands "~" and resolves symlinks, so crawled paths match the paths FSEvents reports.
    static func folderURL(_ path: String) -> URL {
        URL(fileURLWithPath: (path.trimmingCharacters(in: .whitespaces) as NSString).expandingTildeInPath)
            .resolvingSymlinksInPath().standardizedFileURL
    }

    static func isFolder(_ url: URL) -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }
}

/// "~/DigUpTestbed/real" instead of "/Users/…/DigUpTestbed/real".
nonisolated func tildePath(_ path: String) -> String {
    (path as NSString).abbreviatingWithTildeInPath
}
