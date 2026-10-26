import AppKit
import DigUpKit
import Observation
import SwiftUI

/// First launch, in four steps: what 知处 does, which folders to search (with how long the first pass takes), the
/// hotkey (try it), and done; a fifth, code search, when there are folders with code on the Mac (it stays off unless
/// you turn it on there). The model downloads from Get Started on, shown at the bottom of every later step, and
/// the chosen folders start indexing as soon as you continue past them.
final class OnboardingController: NSObject, NSWindowDelegate {
    let state: OnboardingState
    private unowned let app: AppController
    private var window: NSWindow?

    init(app: AppController) {
        self.app = app
        state = OnboardingState(app: app)
    }

    var isVisible: Bool { window?.isVisible == true }

    func show() {
        let window = self.window ?? makeWindow()
        app.present(window)
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: OnboardingView.size.width,
                                                  height: OnboardingView.size.height),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.title = "欢迎使用知处"
        window.isReleasedWhenClosed = false
        window.delegate = self
        state.close = { [weak self] in self?.close() }
        window.contentView = NSHostingView(rootView: OnboardingView(state: state))
        window.center()
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        state.leaving()
        window?.contentView = nil
        window = nil
        app.onboardingClosed()
    }

    func snapshot(to url: URL) throws {
        try Snapshot.write(window, to: url)
    }
}

@Observable
final class OnboardingState {
    enum Step: Int, CaseIterable {
        case welcome, folders, code, shortcut, ready
    }

    private(set) var step = Step.welcome
    /// The folders to search, with their estimates and subfolders; applied on Continue.
    let folders: FolderChoices
    /// Code search's folders, offered when the Mac has folders with code (`CodeFolders`); applied on Continue when
    /// `searchCode` is on.
    let codeFolders: FolderChoices
    var searchCode = false {
        didSet { if searchCode { codeFolders.startEstimates() } }
    }
    /// You pressed the hotkey on the shortcut step.
    private(set) var hotkeyWorked = false
    var launchAtLogin: Bool
    var indexOnBattery: Bool
    /// File types to skip as typed ("heic, txt"): applied on Return, and on Continue (a click there doesn't end the
    /// field's editing).
    var skippedTypesText: String
    @ObservationIgnored let app: AppController
    @ObservationIgnored var close: () -> Void = {}

    init(app: AppController) {
        self.app = app
        let settings = app.model.settings
        let candidates = Self.candidates()
        let chosen = settings.roots
        let selection = FolderSelection(chosen: (chosen.isEmpty ? candidates : chosen).map(\.path),
                                        skipped: settings.excludedFolders.map(\.path))
        // A chosen subfolder of a folder listed shows in that folder's list, not as a folder of its own.
        let others = chosen.filter { root in
            !candidates.contains { $0.path == root.path || $0.path == FolderSelection.parent(root.path) }
        }
        folders = FolderChoices(rows: candidates + others, selection: selection, types: settings.excludedTypes)
        let codeCandidates = CodeFolders.candidates(searched: [])
        codeFolders = FolderChoices(rows: codeCandidates,
                                    selection: FolderSelection(chosen: settings.codeRoots.isEmpty
                                                                   ? codeCandidates.map(\.path)
                                                                   : settings.codeRoots.map(\.path)),
                                    types: [], code: true)
        searchCode = !settings.codeRoots.isEmpty
        launchAtLogin = app.launchesAtLogin || app.suggestsLaunchAtLogin
        indexOnBattery = settings.indexOnBattery
        skippedTypesText = settings.excludedTypes.joined(separator: ", ")
    }

    var model: AppModel { app.model }
    var download: ModelDownload { app.download }

    /// The steps this Mac gets: code search's only when there's code to offer.
    var steps: [Step] {
        Step.allCases.filter { $0 != .code || !codeFolders.rows.isEmpty }
    }

    /// The folders it offers: the usual home folders that exist, or `-onboardingLocations a:b:c` (tests point it at
    /// the testbed, never at real folders).
    static func candidates() -> [URL] {
        if let list = UserDefaults.standard.string(forKey: "onboardingLocations") {
            return list.split(separator: ":").map { AppSettings.folderURL(String($0)) }
        }
        // A dev or test run (its own defaults suite) never offers, and so never estimates, the real home folders.
        if UserDefaults.standard.string(forKey: "defaultsSuite") != nil {
            log("onboarding: no -onboardingLocations in a dev run, so no folders are offered")
            return []
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["Desktop", "文档", "Downloads", "Pictures", "Movies", "Music"]
            .map { AppSettings.folderURL(home.appendingPathComponent($0).path) }
            .filter(AppSettings.isFolder)
    }

    // MARK: Steps

    func next() {
        switch step {
        case .welcome:
            download.start()   // the go-ahead for the one download
            go(to: .folders)
        case .folders:
            // Indexing starts now (file names first; meaning once the model is in), while you set up the rest.
            folders.setTypes(skippedTypesText)
            app.applyFolders(folders.roots, excluded: folders.skipped, types: folders.types)
            go(to: steps.contains(.code) ? .code : .shortcut)
        case .code:
            if searchCode, !codeFolders.roots.isEmpty {
                app.applyCodeFolders(codeFolders.roots, excluded: codeFolders.skipped)
            } else if !searchCode, model.hasCode {
                app.applyCodeFolders([], excluded: [])
            }
            go(to: .shortcut)
        case .shortcut:
            go(to: .ready)
        case .ready:
            finish()
        }
    }

    func back() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        go(to: steps[index - 1])
    }

    func go(to step: Step) {
        self.step = step
        app.hotkeyTester = step == .shortcut ? { [weak self] in self?.hotkeyWorked = true } : nil
        if step == .folders { folders.startEstimates() }
    }

    func finish() {
        if indexOnBattery != model.settings.indexOnBattery { app.setIndexOnBattery(indexOnBattery) }
        if launchAtLogin != app.launchesAtLogin { _ = app.setLaunchAtLogin(launchAtLogin) }
        log("onboarding: done (\(model.settings.roots.count) folders, login item \(launchAtLogin ? "on" : "off"))")
        close()
    }

    /// The window is closing (Done or its close button).
    func leaving() {
        app.hotkeyTester = nil
    }

    // MARK: Folders (applied on Continue, from the first pass on; Settings has the same for later)

    func addFolders(from window: NSWindow?) {
        app.pickFolders(for: window) { [weak self] picked in
            guard !picked.isEmpty else { return }
            self?.folders.add(picked)
        }
    }

    func skipFolders(from window: NSWindow?) {
        app.pickFolders(for: window, prompt: "Skip") { [weak self] picked in
            guard !picked.isEmpty else { return }
            self?.folders.skip(picked)
        }
    }

    /// The step has what it needs to be drawn (debug snapshots wait for this).
    var isLoaded: Bool {
        switch step {
        case .folders: folders.estimatesDone
        case .code: !searchCode || codeFolders.estimatesDone
        default: true
        }
    }

    func addCodeFolders(from window: NSWindow?) {
        app.pickFolders(for: window) { [weak self] picked in
            guard !picked.isEmpty else { return }
            self?.codeFolders.add(picked)
        }
    }
}

// MARK: Views

struct OnboardingView: View {
    static let size = CGSize(width: 680, height: 600)
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch state.step {
                case .welcome: WelcomeStep()
                case .folders: FoldersStep(state: state)
                case .code: CodeStep(state: state)
                case .shortcut: ShortcutStep(state: state)
                case .ready: ReadyStep(state: state)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: state.step == .welcome ? .center : .top)
            .padding(.horizontal, 48)
            .padding(.top, 46)
            Divider()
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(alignment: .top) {
            // A soft moss glow behind the top of each step, from the icon's colors.
            Brand.wash
                .frame(height: 260)
                .mask(LinearGradient(colors: [.black.opacity(0.10), .clear], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            StepDots(current: state.steps.firstIndex(of: state.step) ?? 0, count: state.steps.count)
            if state.step != .welcome {
                DownloadStatus(download: state.download)
            }
            Spacer(minLength: 8)
            if state.step == .folders || state.step == .code && state.searchCode {
                Text(state.step == .code ? codeSummary : foldersSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if state.step != .welcome, state.step != .ready {
                Button("上一步") { state.back() }
            }
            Button(continueTitle) { state.next() }
                .keyboardShortcut(.defaultAction)
                .disabled(state.step == .folders && state.folders.roots.isEmpty)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .frame(height: 64)
    }

    private var continueTitle: String {
        switch state.step {
        case .welcome: "开始使用"
        case .folders: state.folders.roots.isEmpty ? "继续" : "开始索引"
        case .code: "继续"
        case .shortcut: "继续"
        case .ready: "完成"
        }
    }

    private var codeSummary: String {
        guard !state.codeFolders.roots.isEmpty else { return "请选择代码所在的文件夹" }
        guard state.codeFolders.estimatesDone else { return "正在估算代码…" }
        let seconds = state.codeFolders.totalSeconds
        return (seconds < 1 ? "Under a second" : "About \(roughDuration(seconds))")
            + ", \(roughBytes(state.codeFolders.totalBytes))"
    }

    private var foldersSummary: String {
        guard !state.folders.roots.isEmpty else { return "请至少选择一个文件夹" }
        guard state.folders.estimatesDone else { return "正在估算文件夹…" }
        return "首次索引约需 \(roughDuration(state.folders.totalSeconds))"
    }
}

private struct StepDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color.primary.opacity(0.55) : Color.primary.opacity(0.15))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("第 \(current + 1) 步，共 \(count) 步")
    }
}

/// The model download, small: "Downloading the model · 42% · about 1 min left", then "模型已就绪".
struct DownloadStatus: View {
    let download: ModelDownload

    var body: some View {
        HStack(spacing: 7) {
            switch download.phase {
            case .ready:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("模型已就绪")
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(message).lineLimit(1)
                Button("重试") { download.start() }.controlSize(.small)
                Button("导入模型文件…") { download.chooseFiles(for: NSApp.keyWindow) }
                    .controlSize(.small)
                    .help("已从其他地方下载两个模型文件？可在此导入。")
            case .needed:
                Image(systemName: "arrow.down.circle").foregroundStyle(.secondary)
                Text("尚未下载模型")
                Button("下载") { download.start() }.controlSize(.small)
            default:
                ProgressView(value: download.fraction)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                Text("正在下载模型 · \(download.progressText)")
                    .lineLimit(1)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("知处")
                .font(.system(size: 30, weight: .bold))
                .padding(.top, 10)
            Text("记得内容，就能找到。")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 16) {
                Feature(symbol: "camera.viewfinder", title: "截图与照片",
                        example: "“付款失败的截图”“斑马的照片”“周二的白板笔记”")
                Feature(symbol: "doc.text", title: "PDF 与文档",
                        example: "“租房合同里的宠物条款”“机票收据”")
                Feature(symbol: "waveform", title: "录音与视频中的片段",
                        example: "“谈到睡眠的片段”“有鼓声的那一段”")
            }
            .padding(.top, 30)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                Text("索引和搜索均在这台 Mac 上完成。首次需下载约 865 MB 的 AI 模型；"
                     + "之后可离线使用，索引内容不会上传。接下来会查看常用文件夹，"
                     + "估算索引用时；只有你选定的文件夹才会建立索引。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 26)
            .frame(maxWidth: 470, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }
}

private struct Feature: View {
    let symbol: String
    let title: String
    let example: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Brand.tile))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(example).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 470, alignment: .leading)
    }
}

struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 24, weight: .bold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FoldersStep: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle(title: "希望知处搜索哪些文件夹？",
                      subtitle: "选择文件夹，也可展开后仅选择部分子文件夹。之后随时可以"
                          + "在设置中调整。")
            ScrollView {
                VStack(spacing: 6) {
                    FolderList(choices: state.folders, addTitle: "添加文件夹…") {
                        state.addFolders(from: NSApp.keyWindow)
                    }
                    SkipChoices(state: state)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text("读取桌面、文稿和下载等文件夹前，macOS 会请求你的授权。"
                     + "知处仅读取文件，不会修改、移动或上传。")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.bottom, 14)
        }
    }
}

/// Folders and file types to leave out, before the first pass reads anything. Folded away unless something is set.
private struct SkipChoices: View {
    @Bindable var state: OnboardingState
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(state.folders.selection.effectiveSkips, id: \.self) { folder in
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: folder))
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(tildePath(folder)).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button {
                            state.folders.unskip(folder)
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("重新搜索此文件夹")
                    }
                    .font(.system(size: 12))
                }
                Button {
                    state.skipFolders(from: NSApp.keyWindow)
                } label: {
                    Label("排除文件夹…", systemImage: "plus")
                }
                .controlSize(.small)
                HStack(spacing: 8) {
                    Text("文件类型")
                    TextField("扩展名", text: $state.skippedTypesText, prompt: Text("例如 heic, txt"))
                        .labelsHidden()
                        .controlSize(.small)
                        .onSubmit { state.folders.setTypes(state.skippedTypesText) }
                }
                .font(.system(size: 12))
                Text("始终跳过密钥、证书、隐藏文件夹、应用包与缓存；代码使用独立索引。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.leading, 4)
        } label: {
            Text("排除部分文件夹或文件类型")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .onAppear {
            expanded = !state.folders.selection.effectiveSkips.isEmpty || !state.folders.types.isEmpty
        }
    }
}

/// Code search, if you want it: a switch (off until you turn it on), then the folders with code, each opening to its
/// repos with how long reading them takes and the room their index needs, and the editor results open in.
private struct CodeStep: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(title: "也要搜索代码吗？",
                      subtitle: "输入 code: 加上代码作用或名称，即可搜索代码，例如"
                          + "“code: 失败后重试”。代码使用独立索引，不会混入其他"
                          + "搜索结果。之后可在“设置 → 代码”中开启。")
            SwitchRow(title: "开启代码搜索", detail: "默认关闭，由你主动开启。", isOn: $state.searchCode)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
            if state.searchCode {
                ScrollView {
                    VStack(spacing: 6) {
                        FolderList(choices: state.codeFolders, addTitle: "添加文件夹…") {
                            state.addCodeFolders(from: NSApp.keyWindow)
                        }
                        CodeFolderNote().padding(.top, 4)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                HStack {
                    Text("打开代码的应用")
                    Picker("打开代码的应用", selection: Binding(get: { CodeEditor.chosen(state.model.settings.codeEditor).id },
                                                              set: { state.app.setCodeEditor($0) })) {
                        ForEach(CodeEditor.installed) { editor in Text(editor.name).tag(editor.id) }
                        Text(CodeEditor.defaultApp.name).tag(CodeEditor.defaultApp.id)
                    }
                    .labelsHidden()
                    .fixedSize()
                    Spacer()
                }
                .font(.system(size: 12))
                .padding(.bottom, 12)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct ShortcutStep: View {
    let state: OnboardingState

    var body: some View {
        VStack(spacing: 0) {
            StepTitle(title: "随时唤起知处",
                      subtitle: "在任何应用中按下快捷键，描述要找的内容，再按回车打开结果。")
            ShortcutRecorder(combo: state.model.hotkey, apply: { state.app.setHotkey($0) },
                             listening: { state.app.hotkeyRecording($0) }, capSize: 20)
                .padding(.top, 34)
            Group {
                if state.hotkeyWorked {
                    Label("设置成功，可在任何应用中唤起。", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if let hotkey = state.model.hotkey {
                    Text("试试看：按下 \(hotkey.display)。")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.top, 16)
            .animation(.default, value: state.hotkeyWorked)
            VStack(alignment: .leading, spacing: 9) {
                Text("在快捷搜索面板中")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                KeyTip(caps: ["↩"], text: "打开文件")
                KeyTip(caps: ["⌘", "↩"], text: "在 Finder 中显示")
                KeyTip(caps: ["Space"], text: "选中结果后，按空格快速查看")
                KeyTip(caps: ["⌘", "C"], text: "复制文件，粘贴到其他应用")
                KeyTip(caps: ["esc"], text: "关闭")
            }
            .padding(18)
            .frame(maxWidth: 340, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
            .padding(.top, 34)
        }
    }
}

private struct KeyTip: View {
    let caps: [String]
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Keycaps(caps: caps, size: 11)
                .frame(width: 66, alignment: .leading)
            Text(text).font(.system(size: 12))
        }
    }
}

private struct ReadyStep: View {
    @Bindable var state: OnboardingState

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(Brand.gradient)
                .padding(.top, 8)
            Text("准备就绪")
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 14)
            Text(progressNote)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 470)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 16) {
                SwitchRow(title: "登录时启动知处", detail: "让快捷键随时可用。",
                          isOn: $state.launchAtLogin)
                Divider()
                SwitchRow(title: AppSettings.batteryTitle, detail: AppSettings.batteryDetail,
                          isOn: Binding(get: { !state.indexOnBattery }, set: { state.indexOnBattery = !$0 }))
            }
            .padding(20)
            .frame(maxWidth: 470, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
            .padding(.top, 28)
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                Text("知处常驻菜单栏，可随时查看索引进度。")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity)
    }

    private var progressNote: String {
        let seconds = state.folders.totalSeconds, later = state.folders.totalLaterSeconds
        let time = seconds > 0 ? "（约需 \(roughDuration(seconds))）" : ""
        let rest = later >= 30 ? "长篇 PDF 和文档会先处理开头部分，"
            + "其余内容稍后补齐（另需约 \(roughDuration(later))）。" : ""
        if state.download.isReady {
            return "知处正在读取文件夹\(time)，优先处理最新文件。现在就可以搜索；"
                + "结果会随着索引进度逐步补齐。" + rest
        }
        return "模型下载后，知处会开始读取文件夹\(time)"
            + "（\(state.download.progressText)）。此前可先按文件名搜索。" + rest
    }
}

/// A setting with a title, a line about it, and a switch on the right.
struct SwitchRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
    }
}
