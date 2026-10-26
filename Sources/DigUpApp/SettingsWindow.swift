import AppKit
import DigUpKit
import Observation
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general, folders, mail, code, storage

    var title: String {
        switch self {
        case .general: "通用"
        case .folders: "文件夹"
        case .mail: "邮件"
        case .code: "代码"
        case .storage: "存储"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .folders: "folder"
        case .mail: "envelope"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .storage: "internaldrive"
        }
    }
}

/// Settings, the way Mac apps lay them out: a toolbar of tabs, and the window sized to each one. Folders is also where
/// the index shows how far along it is, folder by folder.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    let state: SettingsState
    /// Folders → Add Folders…, a sheet on this window.
    let addSheet: AddFoldersController
    /// Code → Add Folders… (code search's folders), a sheet on this window.
    let codeSheet: AddFoldersController
    private unowned let app: AppController
    private var window: NSWindow?
    private var tabs: NSTabViewController?

    init(app: AppController) {
        self.app = app
        state = SettingsState(app: app)
        addSheet = AddFoldersController(app: app)
        codeSheet = AddFoldersController(app: app, code: true)
        super.init()
        state.addFolders = { [weak self] in self?.addFolders() }
        state.addCodeFolders = { [weak self] in self?.addCodeFolders() }
        for sheet in [addSheet, codeSheet] {
            sheet.onAdded = { [weak self] in
                guard let self else { return }
                Task { await self.state.refresh() }
            }
        }
    }

    /// Opens Add Folders on the Folders tab.
    func addFolders() {
        addSheet.begin(on: window)
    }

    /// Opens the code folders' sheet on the Code tab.
    func addCodeFolders() {
        codeSheet.begin(on: window)
    }

    var isVisible: Bool { window?.isVisible == true }

    func show(_ tab: SettingsTab = .general) {
        let window = self.window ?? makeWindow()
        tabs?.selectedTabViewItemIndex = SettingsTab.allCases.firstIndex(of: tab) ?? 0
        state.tab = tab
        Task { await state.refresh() }
        app.present(window)
    }

    var selectedTab: SettingsTab { state.tab }

    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = [.allowUserInteraction]
        for tab in SettingsTab.allCases {
            let controller = NSHostingController(rootView: SettingsPane(tab: tab, state: state))
            controller.sizingOptions = .preferredContentSize
            controller.title = tab.title   // the window takes the selected tab's title
            let item = NSTabViewItem(viewController: controller)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            item.identifier = tab.rawValue
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.tabs = tabs
        self.window = window
        state.selectTab = { [weak self] tab in
            self?.tabs?.selectedTabViewItemIndex = SettingsTab.allCases.firstIndex(of: tab) ?? 0
        }
        return window
    }

    func windowWillClose(_ notification: Notification) {
        addSheet.end()
        codeSheet.end()
        window?.contentViewController = nil
        window = nil
        tabs = nil
        app.windowClosed()
    }

    func snapshot(to url: URL) throws {
        try Snapshot.write(window, to: url)
    }
}

@Observable
final class SettingsState {
    var tab = SettingsTab.general
    private(set) var summaries: [Engine.RootSummary]?
    private(set) var codeSummaries: [Engine.RootSummary] = []
    private(set) var indexSize: Int64 = 0
    private(set) var codeIndexSize: Int64 = 0
    var launchAtLogin = false
    var retryNotice: String?
    var retrying: Set<String> = []
    var loginProblem: String?
    var checksForUpdates = false
    @ObservationIgnored let app: AppController
    @ObservationIgnored var selectTab: (SettingsTab) -> Void = { _ in }
    @ObservationIgnored var addFolders: () -> Void = {}
    @ObservationIgnored var addCodeFolders: () -> Void = {}

    init(app: AppController) {
        self.app = app
    }

    @ObservationIgnored private var lastRefresh = Date.distantPast
    @ObservationIgnored private var refreshPending = false

    var model: AppModel { app.model }

    func refresh() async {
        lastRefresh = Date()
        launchAtLogin = app.launchesAtLogin
        checksForUpdates = app.updates.automaticallyChecks
        indexSize = app.engine.indexSize
        codeIndexSize = app.engine.codeIndexSize
        codeSummaries = await app.engine.rootSummaries(code: true)
        summaries = await app.engine.rootSummaries()
    }

    func retry(_ summary: Engine.RootSummary, code: Bool = false) {
        guard retrying.insert(summary.path).inserted else { return }
        Task {
            defer { retrying.remove(summary.path) }
            do {
                let count = try await app.engine.retryFailed(in: summary.path, code: code)
                retryNotice = count > 0 ? "已将 \(count) 个文件加入重试队列；暂停、供电和时段设置仍然有效。" : "没有需要重试的文件。"
            } catch { retryNotice = "无法重试：\(error)" }
            await refresh()
        }
    }

    /// The index changed: refresh the folder counts, at most every 2 s while files are being indexed.
    func statusChanged() {
        guard !refreshPending else { return }
        refreshPending = true
        let wait = max(0, 2 - Date().timeIntervalSince(lastRefresh))
        Task {
            try? await Task.sleep(for: .seconds(wait))
            refreshPending = false
            await refresh()
        }
    }

    /// Ready to be drawn (debug snapshots wait for this).
    var isLoaded: Bool { summaries != nil }
}

/// One tab's content, at the width every tab shares.
private struct SettingsPane: View {
    let tab: SettingsTab
    let state: SettingsState
    /// The content's own height. The window is that tall up to what the screen has room for, and scrolls past it (a
    /// long list of folders ran it off the screen, Add Folders… with it).
    @State private var height: CGFloat?

    var body: some View {
        ScrollView(.vertical) {
            Group {
                switch tab {
                case .general: GeneralSettings(state: state)
                case .folders: FolderSettings(state: state)
                case .mail: MailSettings(app: state.app)
                case .code: CodeSettings(state: state)
                case .storage: StorageSettings(state: state)
                }
            }
            .frame(width: 580)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 580, height: height.map { min($0, Self.tallest) })
    }

    /// The screen's room below the menu bar, less the window's title bar and tabs and a margin.
    private static var tallest: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) - 140
    }
}

private struct GeneralSettings: View {
    @Bindable var state: SettingsState

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    ShortcutRecorder(combo: state.model.hotkey, apply: { state.app.setHotkey($0) },
                                     listening: { state.app.hotkeyRecording($0) }, capSize: 13)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("搜索快捷键")
                        Text("在任何应用中打开快捷搜索面板。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Toggle(isOn: Binding(get: { state.launchAtLogin }, set: { on in
                    state.loginProblem = state.app.setLaunchAtLogin(on)
                    state.launchAtLogin = state.app.launchesAtLogin
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("登录时启动知处")
                        Text(state.loginProblem ?? "让快捷键随时可用。")
                            .font(.system(size: 11))
                            .foregroundStyle(state.loginProblem == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    }
                }
            }
            Section {
                Toggle(isOn: Binding(get: { state.checksForUpdates }, set: { on in
                    state.app.updates.automaticallyChecks = on
                    state.checksForUpdates = on
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动检查更新")
                        Text("当前开发版尚未配置知处更新服务。"
                             + "正式更新渠道配置完成后可在此检查。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(!state.app.updates.isConfigured)
                LabeledContent {
                    Button("立即检查") { state.app.updates.checkNow() }
                        .disabled(!state.app.updates.canCheck)
                } label: {
                    Text(state.model.updateAvailable.map { "知处 \($0) 可更新" }
                         ?? "知处 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

private struct FolderSettings: View {
    @Bindable var state: SettingsState
    @State private var removing: Engine.RootSummary?

    var body: some View {
        Form {
            Section {
                SourceIndexProgress(model: state.model, source: .folders) { state.app.engine.setPaused(!state.model.status.paused) }
            }
            Section {
                if let summaries = state.summaries {
                    if summaries.isEmpty {
                        Text("尚未添加文件夹。请选择希望知处搜索的位置。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(summaries) { summary in
                        FolderStatusRow(summary: summary, retry: { state.retry(summary) }, retrying: state.retrying.contains(summary.path)) { removing = summary }
                    }
                } else {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity)
                }
            } header: {
                Text("搜索范围")
            } footer: {
                HStack {
                    Button(action: state.addFolders) {
                        Label("添加文件夹…", systemImage: "plus")
                    }
                    Spacer()
                }
            }
            Section {
                ForEach(state.model.settings.excludedFolders, id: \.path) { folder in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(tildePath(folder.path)).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button {
                            state.app.setExcluded(state.model.settings.excludedFolders.filter { $0 != folder })
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("重新搜索此文件夹")
                    }
                }
                if state.model.settings.excludedFolders.isEmpty {
                    Text("暂无。默认跳过代码项目、应用包和缓存；代码在独立标签中设置。")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("排除这些文件夹")
            } footer: {
                HStack {
                    Button {
                        state.app.pickFolders(for: NSApp.keyWindow, prompt: "排除") { folders in
                            guard !folders.isEmpty else { return }
                            state.app.setExcluded(state.model.settings.excludedFolders
                                + folders.filter { !state.model.settings.excludedFolders.contains($0) })
                        }
                    } label: {
                        Label("排除文件夹…", systemImage: "plus")
                    }
                    Spacer()
                }
            }
            Section {
                TypeExclusions(types: state.model.settings.excludedTypes) { state.app.setExcludedTypes($0) }
            } header: {
                Text("排除这些文件类型")
            } footer: {
                Text("知处在此读取图片、PDF、文档、音频与视频；"
                     + "代码仅在“代码”标签设置的文件夹中读取。密钥、证书和密码文件，"
                     + "以及 ~/.ssh 等隐藏文件夹始终跳过。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                Toggle(isOn: Binding(get: { !state.model.settings.indexOnBattery },
                                     set: { state.app.setIndexOnBattery(!$0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppSettings.batteryTitle)
                        Text(AppSettings.batteryDetail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: Binding(get: { state.model.settings.indexHoursOn }, set: { on in
                    state.app.setIndexHours(on: on, hours: state.model.settings.indexHours)
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("仅在指定时段建立索引")
                        Text("仅在指定时段读取文件；时段外的变更将在下一时段处理。"
                             + "搜索功能全天可用。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if state.model.settings.indexHoursOn {
                    LabeledContent("索引时段") {
                        HStack(spacing: 6) {
                            DatePicker("开始时间", selection: time(\.start), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            Text("至")
                            DatePicker("结束时间", selection: time(\.end), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onChange(of: state.model.status) { state.statusChanged() }
        .alert("重试结果", isPresented: Binding(get: { state.retryNotice != nil }, set: { if !$0 { state.retryNotice = nil } })) {
            Button("好") { state.retryNotice = nil }
        } message: { Text(state.retryNotice ?? "") }
        .confirmationDialog(removalTitle, isPresented: Binding(get: { removing != nil },
                                                               set: { if !$0 { removing = nil } })) {
            Button("移除", role: .destructive) {
                guard let removing else { return }
                state.app.removeFolder(URL(fileURLWithPath: removing.path))
                Task { await state.refresh() }
            }
        } message: {
            Text("这将移除其 \(removing?.files.formatted() ?? "") 个文件的索引。之后重新添加时会再次建立索引，原文件不受影响。")
        }
    }

    private var removalTitle: String {
        "停止搜索“\(removing.map { ($0.path as NSString).lastPathComponent } ?? "")”？"
    }

    /// One end of the set hours, as a time of day for a date picker.
    private func time(_ end: KeyPath<IndexHours, Int>) -> Binding<Date> {
        Binding(get: {
            let minute = state.model.settings.indexHours[keyPath: end]
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let hours = state.model.settings.indexHours
            state.app.setIndexHours(on: true, hours: end == \IndexHours.start ? IndexHours(start: minute, end: hours.end)
                                                                              : IndexHours(start: hours.start, end: minute))
        })
    }
}

/// Extensions typed as "heic, txt": applied on Return or when the field loses focus.
private struct TypeExclusions: View {
    let types: [String]
    let apply: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("扩展名", text: $text, prompt: Text("例如 heic, txt"))
            .labelsHidden()
            .focused($focused)
            .onSubmit { apply(text) }
            .onChange(of: focused) { _, now in if !now { apply(text) } }
            .onAppear { text = types.joined(separator: ", ") }
            .onChange(of: types) { _, now in text = now.joined(separator: ", ") }
    }
}

private struct FolderStatusRow: View {
    let summary: Engine.RootSummary
    let retry: () -> Void
    let retrying: Bool
    let remove: () -> Void
    @State private var showingReasons = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: summary.missing ? "/Volumes" : summary.path))
                .resizable()
                .frame(width: 32, height: 32)
                .opacity(summary.missing ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text((summary.path as NSString).lastPathComponent).font(.system(size: 13, weight: .semibold))
                    if summary.missing || summary.unreadable {
                        Text(summary.missing ? "未连接" : "无访问权限")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                    }
                    if summary.unreadable {
                        Button("在系统设置中授权…", action: openFolderPrivacySettings)
                            .buttonStyle(.link)
                            .font(.system(size: 11))
                    }
                }
                Text(tildePath(summary.path))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !summary.kinds.isEmpty {
                    KindCounts(counts: summary.kinds).padding(.top, 1)
                }
                ForEach(summary.failures.prefix(3)) { issue in
                    VStack(alignment: .leading, spacing: 3) {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: issue.path)])
                        } label: {
                            Label((issue.path as NSString).lastPathComponent, systemImage: "exclamationmark.triangle")
                        }
                        .buttonStyle(.link)
                        .help("在 Finder 中显示：\(issue.path)")
                        Text(Self.readableReason(issue.detail)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 11))
                    .padding(.top, 6)
                }
                if summary.failed > 3 {
                    Text("另有 \(summary.failed - 3) 个失败文件，点击右侧详情查看。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(summary.missing || summary.unreadable ? "保留索引，等待重新连接"
                     : "已索引 \(summary.indexed.formatted()) / \(summary.files.formatted())")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                if !states.isEmpty {
                    if reasons.isEmpty && summary.failures.isEmpty {
                        Text(states).font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        Button { showingReasons.toggle() } label: {
                            HStack(spacing: 3) {
                                Text(states)
                                Image(systemName: "info.circle")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("部分文件无法搜索的原因")
                        .popover(isPresented: $showingReasons, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(reasons, id: \.self) { Text($0) }
                                ForEach(summary.failures) { issue in
                                    Text((issue.path as NSString).lastPathComponent + "：" + Self.readableReason(issue.detail))
                                }
                                if summary.failed > summary.failures.count {
                                    Text("仅显示前 \(summary.failures.count) 个失败文件；可重试本文件夹内全部失败文件。")
                                }
                            }
                            .font(.system(size: 12))
                            .padding(12)
                            .frame(maxWidth: 360, alignment: .leading)
                        }
                    }
                }
                if summary.failed > 0 {
                    Button(retrying ? "正在加入…" : "重试失败文件", action: retry)
                        .controlSize(.small)
                        .disabled(retrying)
                        .padding(.top, 5)
                }
            }
            Button(action: remove) {
                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("停止搜索此文件夹")
            .accessibilityLabel("停止搜索 \((summary.path as NSString).lastPathComponent)")
        }
        .padding(.vertical, 2)
    }

    private static func readableReason(_ reason: String) -> String {
        if reason.contains("ZIP container is not a supported word-processing document") {
            return "文件内容不是受支持的 Word 文档格式，扩展名可能与实际内容不一致。"
        }
        if reason.contains("NSCocoaErrorDomain"), reason.contains("Code=259") {
            return "当前文档解析器无法识别此格式，可能存在兼容性问题，文件不一定损坏。"
        }
        if reason.contains("can't open PDF") || reason.contains("cannot open PDF") { return "无法读取 PDF，文件可能损坏或格式无效。" }
        if reason == "no text" { return "没有可索引的文字。" }
        if reason.contains("silent or shorter") { return "音频无有效语音，或时长不足 2 秒。" }
        if reason.contains("protected") || reason.contains("encrypted") { return "文件受到保护或加密，请先解除保护。" }
        if reason.contains("took more than") || reason.contains("timed out") { return "读取超时，可稍后重试或检查文件。" }
        if reason == "unknown" { return "读取失败，未获得详细原因。" }
        return reason
    }

    private var states: String {
        [summary.pending > 0 ? "\(summary.pending.formatted()) 个等待处理" : nil,
         summary.unfinished > 0
            ? "\(summary.unfinished.formatted()) 个长文件尚未读完" : nil,
         summary.skipped > 0 ? "\(summary.skipped.formatted()) 个已跳过" : nil,
         summary.failed > 0 ? "\(summary.failed.formatted()) 个读取失败" : nil,
         summary.leftOutCount > 0 ? "\(summary.leftOutCount.formatted()) 个未读取" : nil].compactMap { $0 }
            .joined(separator: " · ")
    }

    /// One line per reason: what the crawl never queued from this folder, then what was skipped once read.
    private var reasons: [String] {
        let crawl: [String: String] = [
            "other type": "个不支持的文件类型",
            "app or bundle": "个应用包内文件",
            "Photos library": "个照片图库内文件（尚不读取图库）",
            "link or special file": "个链接或特殊文件",
            "in the cloud, not downloaded": "个尚未下载到本机的云端文件",
            "inside a code project": "个代码项目内文件",
            "dataset": "个数据集文件夹内文件",
            "code or data file": "个代码或数据文件",
            "excluded type": "个已排除类型的文件",
        ]
        let leftOut = summary.leftOut.sorted { $0.value > $1.value }.map { reason, count in
            reason.hasPrefix("folders ") ? "\(count.formatted()) 个文件夹无法打开（\(reason.dropFirst(8))）"
                : "\(count.formatted()) \(crawl[reason] ?? reason)"
        }
        let skipped = summary.skippedReasons.sorted { $0.value > $1.value }.map { "\($1.formatted()) 个已跳过：\(Self.readableReason($0))" }
        return leftOut + skipped
    }
}

private struct StorageSettings: View {
    let state: SettingsState

    var body: some View {
        Form {
            Section {
                LabeledContent("EmbeddingGemma 2") {
                    Text("Google · Apache 2.0 · 约 865 MB")
                }
                LabeledContent("状态") {
                    HStack(spacing: 8) {
                        Text(state.model.download.isReady ? "已下载" : state.model.download.progressText)
                        switch state.model.download.phase {
                        case .needed, .failed:
                            Button("下载") { state.model.download.start() }.controlSize(.small)
                            Button("导入模型文件…") { state.model.download.chooseFiles(for: NSApp.keyWindow) }
                                .controlSize(.small)
                        default:
                            EmptyView()
                        }
                    }
                }
                LabeledContent("位置") {
                    PathButton(url: state.model.settings.modelsDirectory)
                }
            } header: {
                Text("模型")
            } footer: {
                if !state.model.download.isReady {
                    HStack(alignment: .firstTextBaseline) {
                        Text("如果无法连接 Hugging Face，可从其他网络下载两个模型文件，"
                             + "点击“导入模型文件…”选择文件，知处会在使用前校验完整性。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("复制下载链接") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(ModelDownload.links, forType: .string)
                        }
                        .controlSize(.small)
                        .help("复制两个模型文件的下载地址")
                    }
                }
            }
            Section("索引") {
                LabeledContent("磁盘占用", value: bytes(state.indexSize))
                if state.model.hasCode {
                    LabeledContent("代码索引", value: bytes(state.codeIndexSize))
                }
                LabeledContent("位置") {
                    PathButton(url: state.model.settings.indexDirectory)
                }
            }
            Section("隐私") {
                Text("知处仅读取你选择的文件夹，并在本机保存索引。"
                     + "联网用于下载模型，以及配置更新服务后的版本检查；"
                     + "不会发送你的文件内容。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                Text("知处 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · "
                     + "使用 Google 的 EmbeddingGemma 2（Apache 2.0），由 llama.cpp（MIT）运行。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

/// Code search: its folders and how far along their index is, the editor results open in, and turning it off.
private struct CodeSettings: View {
    @Bindable var state: SettingsState
    @State private var turningOff = false
    @State private var removing: Engine.RootSummary?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("搜索你的代码").font(.system(size: 13, weight: .semibold))
                    Text("在搜索面板中输入 code: 加上代码作用或名称，例如"
                         + "“code: 带退避的请求重试”。代码使用独立索引，"
                         + "不会出现在其他搜索结果中。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if state.model.hasCode {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(state.model.codeStatusLine).font(.system(size: 12, weight: .medium))
                            if let indexing = state.model.status.code.indexing, indexing.total > 0 {
                                ProgressView(value: Double(indexing.done) / Double(indexing.total)).controlSize(.small)
                            }
                        }
                        Spacer()
                        Text(bytes(state.codeIndexSize))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                if state.codeSummaries.isEmpty {
                    Text("尚未添加代码文件夹。请选择项目所在的目录。")
                        .foregroundStyle(.secondary)
                }
                ForEach(state.codeSummaries) { summary in
                    FolderStatusRow(summary: summary, retry: { state.retry(summary, code: true) }, retrying: state.retrying.contains(summary.path)) { removing = summary }
                }
            } header: {
                Text("代码文件夹")
            } footer: {
                HStack {
                    Button(action: state.addCodeFolders) {
                        Label(state.model.hasCode ? "添加文件夹…" : "选择代码文件夹…", systemImage: "plus")
                    }
                    Spacer()
                }
            }
            if state.model.hasCode {
                Section {
                    ForEach(state.model.settings.codeExcluded, id: \.path) { folder in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text(tildePath(folder.path)).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button {
                                state.app.applyCodeFolders(state.model.settings.codeRoots,
                                                           excluded: state.model.settings.codeExcluded.filter { $0 != folder })
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("重新搜索此文件夹中的代码")
                        }
                    }
                    if state.model.settings.codeExcluded.isEmpty {
                        Text("暂无。默认跳过 git 忽略项、第三方依赖和生成代码。")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("排除这些文件夹")
                } footer: {
                    HStack {
                        Button {
                            state.app.pickFolders(for: NSApp.keyWindow, prompt: "排除") { folders in
                                guard !folders.isEmpty else { return }
                                let excluded = state.model.settings.codeExcluded
                                state.app.applyCodeFolders(state.model.settings.codeRoots,
                                                           excluded: excluded + folders.filter { !excluded.contains($0) })
                            }
                        } label: {
                            Label("排除文件夹…", systemImage: "plus")
                        }
                        Spacer()
                    }
                }
            }
            Section {
                Picker("打开代码的应用", selection: Binding(get: { CodeEditor.chosen(state.model.settings.codeEditor).id },
                                                          set: { state.app.setCodeEditor($0) })) {
                    ForEach(CodeEditor.installed) { editor in Text(editor.name).tag(editor.id) }
                    Text(CodeEditor.defaultApp.name).tag(CodeEditor.defaultApp.id)
                }
            } footer: {
                Text("打开结果时定位到命中行；按空格可快速查看整个文件。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Section {
                Text("代码索引与文档索引一样，仅将内容保存在这台 Mac 上。"
                     + "知处会跳过 git 忽略项、第三方依赖、生成代码、数据文件，"
                     + "以及疑似密钥或密码的文件。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if state.model.hasCode {
                    HStack {
                        Spacer()
                        Button("关闭代码搜索…", role: .destructive) { turningOff = true }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onChange(of: state.model.status) { state.statusChanged() }
        .alert("重试结果", isPresented: Binding(get: { state.retryNotice != nil }, set: { if !$0 { state.retryNotice = nil } })) {
            Button("好") { state.retryNotice = nil }
        } message: { Text(state.retryNotice ?? "") }
        .confirmationDialog("关闭代码搜索？", isPresented: $turningOff) {
            Button("关闭", role: .destructive) {
                state.app.applyCodeFolders([], excluded: [])
                Task { await state.refresh() }
            }
        } message: {
            Text("这将删除代码索引（\(bytes(state.codeIndexSize))）。重新开启后会再次建立索引，源文件不受影响。")
        }
        .confirmationDialog("停止搜索“\(removing.map { ($0.path as NSString).lastPathComponent } ?? "")”中的代码？",
                            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button("移除", role: .destructive) {
                guard let removing else { return }
                state.app.removeCodeFolder(URL(fileURLWithPath: removing.path))
                Task { await state.refresh() }
            }
        } message: {
            Text("这将从代码索引中移除 \(removing?.files.formatted() ?? "") 个代码文件，源文件不受影响。")
        }
    }
}

/// "~/Library/…/Models" that shows the folder in Finder.
private struct PathButton: View {
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } label: {
            HStack(spacing: 4) {
                Text(tildePath(url.path)).lineLimit(1).truncationMode(.middle)
                Image(systemName: "arrow.right.circle.fill").foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help("在 Finder 中显示")
    }
}
