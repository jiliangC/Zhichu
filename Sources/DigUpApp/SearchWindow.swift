import AppKit
import DigUpKit
import Observation
import Quartz
import SwiftUI

/// The search window, for the searches the panel is too small for: a big field, kind filters with counts, the results
/// as a grid of pictures, and the selected one in a preview pane with why it matched. The Dock icon shows while it's
/// open, and closing it frees its views (the app goes back to its idle size).
final class SearchWindowController: NSObject, NSWindowDelegate {
    let search: SearchModel
    private unowned let app: AppController
    private var window: QuickLookWindow?
    private var keyMonitor: Any?
    private var mouseMonitor: Any?

    init(app: AppController) {
        self.app = app
        search = SearchModel(engine: app.engine)
    }

    var isVisible: Bool { window?.isVisible == true }

    func show(query: String? = nil, kind: ResultGroupKind? = nil, folder: String? = nil) {
        let window = self.window ?? makeWindow()
        if let query {
            search.filter = kind
            search.query = query
            search.selectFolder(folder)
        }
        app.present(window)
        if !AppController.offscreen { window.makeFirstResponder(search.field) }
        installKeyMonitor()
    }

    func close() {
        window?.close()
    }

    private func makeWindow() -> QuickLookWindow {
        let window = QuickLookWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 700),
                                     styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                     backing: .buffered, defer: false)
        // An empty unified toolbar makes the title bar tall enough for the search field to sit beside the window
        // buttons.
        window.toolbar = NSToolbar(identifier: "DigUpSearch")
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "知处"
        window.minSize = NSSize(width: 820, height: 520)
        window.isReleasedWhenClosed = false
        window.delegate = self
        // The frame is remembered in the app's real defaults, so dev runs (their own -defaultsSuite) don't keep it.
        if UserDefaults.standard.string(forKey: "defaultsSuite") == nil {
            window.setFrameAutosaveName("DigUpSearchWindow")
        }
        window.contentView = NSHostingView(rootView: SearchWindowView(search: search, model: app.model, app: app))
        if window.frame.origin == .zero { window.center() }
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isVisible {
            QLPreviewPanel.shared().orderOut(nil)
        }
        removeKeyMonitor()
        PreviewPlayback.shared.stop()
        window?.contentView = nil
        window = nil
        app.windowClosed()
    }

    func snapshot(to url: URL) throws {
        try Snapshot.write(window, to: url)
    }

    // MARK: Keys

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window else { return event }
            // Keys typed here, or in Quick Look while this window is the one showing it (not the panel's).
            let previewing = QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
                && event.window === QLPreviewPanel.shared() && QLPreviewPanel.shared().dataSource === window
            guard event.window === window || previewing else { return event }
            return handle(event) ? nil : event
        }
        // A click back in the search field: Space and ← → type again (after a click on a result, they were its).
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let window, event.window === window, let field = search.field else { return event }
            if field.bounds.contains(field.convert(event.locationInWindow, from: nil)) { search.editing() }
            return event
        }
    }

    private func removeKeyMonitor() {
        for monitor in [keyMonitor, mouseMonitor].compactMap({ $0 }) { NSEvent.removeMonitor(monitor) }
        keyMonitor = nil
        mouseMonitor = nil
    }

    /// Arrows move through the grid (← → only once you've arrowed, so they still move the cursor while you type),
    /// ↩ opens, ⌘↩ reveals, Space previews, ⌘C copies, Esc closes the preview or clears the search.
    private func handle(_ event: NSEvent) -> Bool {
        // An input method is composing (Japanese, Chinese…): ↩, the arrows and Esc are its keys until it's done.
        if (search.field?.currentEditor() as? NSTextView)?.hasMarkedText() == true { return false }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        let previewing = QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
        switch event.keyCode {
        case 125, 126:   // ↓ ↑
            guard modifiers.isEmpty else { return false }
            search.move(by: event.keyCode == 125 ? search.columns : -search.columns)
        case 123, 124:   // ← →
            guard modifiers.isEmpty, search.navigated || previewing else { return false }
            search.move(by: event.keyCode == 124 ? 1 : -1)
        case 36, 76:   // ↩
            guard let row = search.selectedRow else { return false }
            if modifiers == .command {
                if row.isMail { MailActions.openOriginal(row) }
                else { NSWorkspace.shared.activateFileViewerSelecting([row.url]) }
            } else if modifiers.isEmpty {
                search.open(row)
            } else {
                return false
            }
        case 49 where modifiers.isEmpty && (search.navigated || previewing) && search.selectedRow != nil:   // Space
            toggleQuickLook()
        case 16 where modifiers == .command:   // ⌘Y
            toggleQuickLook()
        case 18...23 where modifiers == .command:   // ⌘1 all, ⌘2…⌘6 one kind
            let kinds: [ResultGroupKind?] = [nil, .screenshots, .images, .documents, .video, .audio]
            let index = [18, 19, 20, 21, 23, 22].firstIndex(of: Int(event.keyCode)) ?? 0   // key codes of 1…6
            search.filter = kinds[index]
        case 28 where modifiers == .command:   // ⌘8: mail
            search.filter = .mail
        case 26 where modifiers == .command && app.model.hasCode:   // ⌘7: code
            search.filter = .code
        case 8 where modifiers == .command && search.navigated:   // ⌘C
            guard let row = search.selectedRow else { return false }
            if row.isMail { MailActions.copyLink(row) }
            else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([row.url as NSURL])
            }
        case 53:   // Esc
            if previewing {
                QLPreviewPanel.shared().orderOut(nil)
            } else if !search.query.isEmpty {
                search.query = ""
            } else {
                return false
            }
        default:
            return false
        }
        if QLPreviewPanel.sharedPreviewPanelExists(), QLPreviewPanel.shared().isVisible { updateQuickLook() }
        return true
    }

    func toggleQuickLook() {
        let panel = QLPreviewPanel.shared()!
        if QLPreviewPanel.sharedPreviewPanelExists(), panel.isVisible {
            panel.orderOut(nil)
        } else if search.selectedRow != nil {
            updateQuickLook()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Quick Look shows the selected result at its page or moment.
    private func updateQuickLook() {
        window?.previewURL = search.selectedRow?.quickLookURL
        QLPreviewPanel.shared().reloadData()
        QuickLookMoment.show(search.selectedRow, in: QLPreviewPanel.shared())
    }
}

/// A window that hands Quick Look the selected file (Space / ⌘Y).
final class QuickLookWindow: NSWindow, QLPreviewPanelDataSource {
    var previewURL: URL?

    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }

    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { panel.dataSource = self }
    }

    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { panel.dataSource = nil }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        previewURL as NSURL?
    }
}

/// The window's query: keyword and meaning results together after a short pause in typing, optionally of one kind.
@Observable
final class SearchModel {
    var query = "" {
        didSet { if query != oldValue { run() } }
    }
    var filter: ResultGroupKind? {
        didSet { if filter != oldValue { run() } }
    }
    private(set) var folders = SearchFolders()
    private(set) var scopeNotice: String?
    var folder: String? { folders.selected(code: isCode) }

    func selectFolder(_ folder: String?) {
        scopeNotice = nil
        guard folder != self.folder else { return }
        folders.select(folder, code: isCode)
        clearResults()
        run()
    }

    func refreshFolders(content: [String], code: [String]) {
        if folders.validate(content: content, code: code) {
            scopeNotice = "搜索范围已重置"
        }
        clearResults()
        run()
    }

    private func clearResults() {
        results = .empty
        counts = [:]
        hasResults = false
        selection = nil
        showWeaker = false
    }

    private(set) var results = ResultSet.empty
    /// Results per kind for the query, whatever the filter (the counts on the kind buttons).
    private(set) var counts: [ResultGroupKind: Int] = [:]
    private(set) var hasResults = false
    /// What the window shows instead of results: "code:" alone (what to type), or code search that's off.
    private(set) var codePhase: SearchPhase?
    var selection: String?
    var showWeaker = false
    var showsPreview = true
    /// You moved the selection with the arrow keys since the last edit: Space and ← → act on results then.
    private(set) var navigated = false
    /// The grid's columns right now (↑ ↓ move by a row).
    var columns = 4
    @ObservationIgnored weak var field: NSTextField?
    @ObservationIgnored private let engine: Engine
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    init(engine: Engine) {
        self.engine = engine
    }

    /// Every result shown, in order (strong ones, then the weaker ones once they're unfolded).
    var rows: [ResultRow] { results.ranked + (showWeaker ? results.weaker : []) }

    /// A search of code: the Code filter, or "code:" typed.
    var isCode: Bool { filter == .code || CodeQuery.text(of: query) != nil }
    var selectedRow: ResultRow? { rows.first { $0.id == selection } ?? rows.first }

    /// A click on a result: like the arrow keys, it makes Space and ← → act on the results.
    func select(_ row: ResultRow) {
        selection = row.id
        navigated = true
    }

    /// A click in the search field: keys are the text's again.
    func editing() {
        navigated = false
    }

    /// Puts the cursor in the search field (a click on the empty window lands there).
    func focusField() {
        guard let field, field.currentEditor() == nil else { return }
        field.window?.makeFirstResponder(field)
    }

    /// The file in its app, at the page or moment that matched when the app can be told where.
    func open(_ row: ResultRow) {
        engine.open(row)
    }

    func move(by step: Int) {
        let ids = rows.map(\.id)
        guard !ids.isEmpty else { return }
        let index = selection.flatMap { ids.firstIndex(of: $0) } ?? -1
        selection = ids[max(0, min(ids.count - 1, index + step))]
        navigated = true
    }

    func indexChanged() {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { run() }
    }

    private func run() {
        generation += 1
        let current = generation
        task?.cancel()
        navigated = false
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = isCode
        let text = CodeQuery.text(of: typed) ?? typed
        codePhase = nil
        guard !typed.isEmpty else {
            results = .empty
            counts = [:]
            hasResults = false
            return
        }
        if code, !engine.hasCode || text.isEmpty {
            results = .empty
            counts = [:]
            hasResults = false
            codePhase = engine.hasCode ? .codeHint : .codeOff
            return
        }
        engine.prewarm()
        engine.embedAhead(text, code: code)
        let filter = self.filter
        let folder = self.folder
        let showAt = ContinuousClock.now + SearchPanelController.typingPause
        if code {
            task = Task {
                let vector = await engine.embedQuery(text, code: true)
                guard !Task.isCancelled, current == generation else { return }
                let hits = await engine.search(text, vector: vector, prefixLast: false, limit: 120, code: true, folder: folder)
                try? await Task.sleep(until: showAt, tolerance: .milliseconds(1), clock: .continuous)
                guard !Task.isCancelled, current == generation else { return }
                counts = [.code: Searcher.strongCount(hits)]
                results = ResultSet(hits, query: text)
                showWeaker = false
                if !rows.contains(where: { $0.id == selection }) { selection = rows.first?.id }
                hasResults = true
                log("window: code \"\(text)\": \(results.ranked.count) results + \(results.weaker.count) weaker")
            }
            return
        }
        task = Task {
            let vector = await engine.embedQuery(text)
            guard !Task.isCancelled, current == generation else { return }
            let all = await engine.search(text, vector: vector, prefixLast: false, limit: 120, folder: folder)
            let shown = filter == nil ? all : await engine.search(text, vector: vector, prefixLast: false,
                                                                    kinds: filter!.kinds, limit: 120, folder: folder)
            try? await Task.sleep(until: showAt, tolerance: .milliseconds(1), clock: .continuous)
            guard !Task.isCancelled, current == generation else { return }
            var counts: [ResultGroupKind: Int] = [:]
            for hit in all.prefix(Searcher.strongCount(all)) { counts[hit.info["mail_id"] != nil ? .mail : ResultGroupKind(hit.kind), default: 0] += 1 }
            self.counts = counts
            results = ResultSet(shown, query: text)
            showWeaker = false
            if !rows.contains(where: { $0.id == selection }) { selection = rows.first?.id }
            hasResults = true
            log("window: \"\(text)\"\(filter.map { " in \($0.title)" } ?? ""): \(results.ranked.count) results "
                + "+ \(results.weaker.count) weaker")
        }
    }
}

// MARK: Views

struct SearchWindowView: View {
    @Bindable var search: SearchModel
    let model: AppModel
    let app: AppController
    @State private var fieldFocused = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if search.showsPreview, let row = search.selectedRow, search.hasResults {
                    Divider()
                    Group {
                    if row.isMail { MailReaderPane(row: row, open: { search.open(row) }) }
                    else { ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            PreviewPane(row: row, imageSize: CGSize(width: 292, height: 230),
                                        open: { search.open(row) })
                            PreviewActions(row: row, open: { search.open(row) },
                                           reveal: { NSWorkspace.shared.activateFileViewerSelecting([row.url]) })
                        }
                        .padding(16)
                    }
                    }
                    }
                    .frame(width: search.selectedRow?.isMail == true ? 462 : 324)
                    .background(Color.primary.opacity(0.025))
                }
            }
            Divider()
            statusBar
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 820, minHeight: 520)
        .onChange(of: model.status.activity) { _, activity in
            if activity == .idle { search.indexChanged() }
        }
        .task(id: model.status.vectors) {
            try? await Task.sleep(for: .milliseconds(250))
            if !Task.isCancelled { search.indexChanged() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: search.isCode ? FileKind.code.symbol : "magnifyingglass")
                        .font(.system(size: search.isCode ? 15 : 17, weight: .semibold))
                        .foregroundStyle(Brand.iconAccent)
                        .frame(width: 22)
                    SearchField(text: $search.query, fontSize: 18, placeholder: placeholder,
                                onMake: { search.field = $0 }, onFocus: { fieldFocused = $0 })
                    if !search.query.isEmpty {
                        Button {
                            search.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("清空搜索")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
                // Where typing goes, as a Mac text field shows it: a ring in the accent color while it has the cursor.
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(fieldFocused ? 0.6 : 0), lineWidth: 2))
                .animation(.easeOut(duration: 0.15), value: fieldFocused)
                Button {
                    search.showsPreview.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 15))
                        .foregroundStyle(search.showsPreview ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.plain)
                .help(search.showsPreview ? "隐藏预览" : "显示预览")
                Button {
                    app.showSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("设置（⌘,）")
            }
            .padding(.leading, 78)   // beside the window buttons
            .frame(height: 52)
            HStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    KindFilters(search: search, showsCode: model.hasCode)
                }
                .frame(height: 28)
                SearchScopePicker(folder: search.folder,
                                  roots: search.isCode ? model.settings.codeRoots : model.settings.roots,
                                  mail: search.isCode ? nil : model.mail,
                                  select: { search.selectFolder($0) },
                                  manage: { app.showSettings(search.isCode ? .code : .folders) })
                    .frame(width: 170, height: 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder private var content: some View {
        if !model.hasFolders, search.filter != .mail {
            VStack(spacing: 0) {
                BrandMark()
                Text("选择要搜索的文件夹").font(.system(size: 20, weight: .bold)).padding(.top, 18)
                Text("只在你指定的位置查找资料。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                Button("选择文件夹…") { app.chooseFolders() }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 18)
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if search.filter == .mail, !model.settings.mail.enabled || model.mail?.isAvailable != true {
            VStack(spacing: 12) {
                if model.mail?.syncing == true { ProgressView().controlSize(.small) }
                EmptyState(symbol: "envelope", title: model.settings.mail.enabled ? "邮件来源暂不可用" : "开启邮件搜索",
                    message: model.settings.mail.enabled ? (model.mail?.problem ?? "正在检查本机邮件…") : "在邮件设置中开启 Apple Mail，选择需要搜索的账号、邮箱和附件范围。")
                Button("邮件设置…") { app.showSettings(.mail) }.padding(.bottom, 30)
            }
        } else if search.query.trimmingCharacters(in: .whitespaces).isEmpty {
            SearchHome(search: search, model: model, engine: app.engine)
        } else if let phase = search.codePhase {
            CodeOffOrHint(phase: phase, search: search) { app.chooseCodeFolders() }
        } else if !search.hasResults {
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if search.results.isEmpty {
            VStack(spacing: 12) {
                EmptyState(symbol: search.isCode ? FileKind.code.symbol : "magnifyingglass",
                           title: search.folder.map { "在 \((model.mail?.scopeName($0) ?? SearchFolders.name($0))) 中未找到合适的结果" }
                               ?? "未找到“\(search.query.trimmingCharacters(in: .whitespaces))”的合适结果",
                           message: search.isCode ? "试试描述代码的作用，或输入代码中的名称。"
                               : "试试描述文件内容，例如看到的画面、听到的声音，或记得的文字。")
                if search.folder != nil {
                    Button(model.mail?.isAvailable == true ? "搜索所有来源" : "搜索所有文件夹") { search.selectFolder(nil) }
                        .padding(.bottom, 32)
                }
            }
        } else if search.filter == .mail {
            MailResultsList(search: search)
        } else if search.isCode {
            CodeResultsList(search: search)
        } else {
            ResultsGrid(search: search)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if let progress = model.progress {
                ProgressView(value: progress).progressViewStyle(.circular).controlSize(.mini)
            }
            // What's indexed: a click shows the folders and their progress.
            Button(model.statusLine) { app.showSettings(.folders) }
                .buttonStyle(.plain)
                .lineLimit(1)
                .help("文件夹与索引进度")
            Spacer()
            if let notice = search.scopeNotice {
                Text(notice).lineLimit(1)
            }
            if let folder = search.folder {
                Text("\((model.mail?.scopeName(folder) ?? SearchFolders.name(folder))) 内").lineLimit(1).help(model.mail?.scopeName(folder) ?? tildePath(folder))
            }
            if search.hasResults, !search.query.isEmpty {
                Text(model.resultsCaveat ?? resultCount).lineLimit(1)
            }
            if let version = model.updateAvailable {
                Button {
                    app.updates.checkNow()
                } label: {
                    Label("知处 \(version) 可更新", systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(Brand.ember)
                }
                .buttonStyle(.plain)
                .help("查看新版本并更新")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 28)
    }

    /// Examples of what to type: code's with the Code chip on, and one of them with code search on (as the panel's).
    private var placeholder: String {
        if search.filter == .code { return "描述代码作用，或输入代码中的名称…" }
        return model.hasCode ? "描述你记得的内容，也可输入 code: 搜索代码…"
            : "描述你记得的内容，例如“付款收据”“海边的小狗”…"
    }

    private var resultCount: String {
        let count = search.results.ranked.count
        return (count == 1 ? "1 个结果" : "\(count) 个结果")
            + (search.results.weaker.isEmpty ? "" : " · \(search.results.weaker.count) 个较弱匹配")
    }
}

/// All · Screenshots 4 · Images 9 · …: what the query found of each kind; click to see only that kind. With code search
/// on, Code after them: a search of code alone (as "code:" is).
private struct KindFilters: View {
    @Bindable var search: SearchModel
    var showsCode = false

    var body: some View {
        HStack(spacing: 6) {
            chip(title: "全部类型", symbol: nil, count: nil, selected: search.filter == nil && !search.isCode) {
                search.filter = nil
            }
            ForEach(ResultGroupKind.files, id: \.self) { kind in
                chip(title: kind.title, symbol: kind.symbol, count: search.isCode ? nil : search.counts[kind],
                     selected: search.filter == kind && !search.isCode, shortcut: kind == .mail ? 8 : nil) {
                    search.filter = search.filter == kind ? nil : kind
                }
            }
            if showsCode {
                Divider().frame(height: 16).padding(.horizontal, 4)
                chip(title: "代码", symbol: FileKind.code.symbol, count: search.isCode ? search.counts[.code] : nil,
                     selected: search.isCode, shortcut: 7) {
                    search.filter = search.filter == .code ? nil : .code
                }
            }
        }
    }

    private func chip(title: String, symbol: String?, count: Int?, selected: Bool, shortcut: Int? = nil,
                      action: @escaping () -> Void) -> some View {
        let number = shortcut ?? ([ResultGroupKind.screenshots, .images, .documents, .video, .audio].firstIndex { $0.title == title }).map { $0 + 2 } ?? 1
        return Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.system(size: 10.5)) }
                Text(title)
                if let count, !search.query.isEmpty {
                    Text("\(count)").monospacedDigit().opacity(0.6)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(selected ? AnyShapeStyle(Color.accentColor)
                                                : AnyShapeStyle(Color.primary.opacity(0.06))))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("\(title) (⌘\(number))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ResultsGrid: View {
    @Bindable var search: SearchModel
    private static let cell = CGSize(width: 176, height: 132)

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.cell.width, maximum: 230), spacing: 14)],
                              alignment: .leading, spacing: 18) {
                        ForEach(search.results.ranked) { row in cell(row) }
                    }
                    .padding(16)
                    if !search.results.weaker.isEmpty {
                        WeakerToggle(count: search.results.weaker.count, expanded: search.showWeaker) {
                            search.showWeaker.toggle()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        if search.showWeaker {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.cell.width, maximum: 230),
                                                         spacing: 14)], alignment: .leading, spacing: 18) {
                                ForEach(search.results.weaker) { row in cell(row).opacity(0.85) }
                            }
                            .padding(16)
                        }
                    }
                }
                .onChange(of: search.selection) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) } }
                }
            }
            .onAppear { updateColumns(geometry.size.width) }
            .onChange(of: geometry.size.width) { _, width in updateColumns(width) }
        }
    }

    private func updateColumns(_ width: CGFloat) {
        search.columns = max(1, Int((width - 32 + 14) / (Self.cell.width + 14)))
    }

    private func cell(_ row: ResultRow) -> some View {
        GridCell(row: row, selected: row.id == search.selectedRow?.id)
            .id(row.id)
            .overlay(FileDragArea(url: row.url, openTitle: row.openTitle, onClick: { search.select(row) },
                                  onOpen: { search.open(row) }))
    }
}

private struct GridCell: View {
    let row: ResultRow
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // A fixed box the picture fills and is clipped to: a picture's own shape must never size the cell.
            Color.primary.opacity(0.05)
                .frame(height: 132)
                .frame(maxWidth: .infinity)
                .overlay {
                    if row.kind == .audio {
                        Image(systemName: "waveform")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(Brand.iconAccent)
                    } else if (row.kind == .doc || row.kind == .mail) && !row.usesPresentationPreview {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: row.isMail ? "envelope" : "doc.text").foregroundStyle(Brand.moss)
                                Text(row.isMail ? "邮件" : row.url.pathExtension.uppercased())
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                            }
                            Text(row.excerpt.map { $0.replacingOccurrences(of: "«", with: "").replacingOccurrences(of: "»", with: "") }
                                 ?? row.name)
                                .font(.system(size: 12)).lineLimit(4).foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: 0)
                        }.padding(.horizontal, 16).padding(.top, 32).padding(.bottom, 12)
                    } else {
                        MomentThumbnail(row: row)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topLeading) {
                if row.kind != .image && row.kind != .screenshot {
                    Image(systemName: row.kind.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(.black.opacity(0.5)))
                        .padding(6)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let place = row.place { PlaceBadge(text: place, onImage: true).padding(6) }
            }
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 3 : 0.5)
                .padding(selected ? -3 : 0))
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(row.folder)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.kind.title), \(row.name), \(row.reason)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Code results, one under another: the file, where in its repo, the lines that matched, and why.
private struct CodeResultsList: View {
    @Bindable var search: SearchModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(search.results.ranked) { row in item(row) }
                    if !search.results.weaker.isEmpty {
                        WeakerToggle(count: search.results.weaker.count, expanded: search.showWeaker) {
                            search.showWeaker.toggle()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        if search.showWeaker {
                            ForEach(search.results.weaker) { row in item(row).opacity(0.85) }
                        }
                    }
                }
                .padding(12)
            }
            .onChange(of: search.selection) { _, id in
                if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) } }
            }
            .onAppear { search.columns = 1 }
        }
    }

    private func item(_ row: ResultRow) -> some View {
        CodeResultRow(row: row, selected: row.id == search.selectedRow?.id)
            .id(row.id)
            .overlay(FileDragArea(url: row.url, openTitle: row.openTitle, onClick: { search.select(row) },
                                  onOpen: { search.open(row) }))
    }
}

private struct CodeResultRow: View {
    let row: ResultRow
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ThumbnailView(url: row.url, version: row.previewKey, side: 30, iconOnly: true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    if let place = row.place { PlaceBadge(text: place) }
                    Text(row.folder)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                if let excerpt = row.excerpt {
                    Text(highlighted(excerpt, size: 11))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.22) : Color.clear))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("代码，\(row.name)，\(row.reason)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "code:" typed without code search on (how to turn it on), or with nothing after it (what to type).
private struct CodeOffOrHint: View {
    let phase: SearchPhase
    let search: SearchModel
    let chooseFolders: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: FileKind.code.symbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Brand.gradient)
            if phase == .codeOff {
                Text("代码搜索尚未开启").font(.system(size: 17, weight: .semibold))
                Text("知处可按作用搜索选定文件夹中的代码。代码使用独立索引，"
                     + "不会混入其他搜索结果。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Button("选择代码文件夹…", action: chooseFolders).padding(.top, 6)
            } else {
                Text("搜索你的代码").font(.system(size: 17, weight: .semibold))
                Text("描述代码的作用，或输入代码中的名称。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A grid cell's picture: the video frame or PDF page that matched (from the preview cache), else Quick Look's.
private struct MomentThumbnail: View {
    let row: ResultRow
    @State private var image: NSImage?
    @State private var imageKey: NSString?
    @State private var request = PreviewRequestGate()
    @Environment(\.displayScale) private var scale

    var body: some View {
        Group {
            if let image, imageKey == Previews.shared.key(row, 230, scale: scale) {
                // A page shows its top (its title), anything else its middle.
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: row.page == nil ? .center : .top)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: row.url.path))
                    .resizable()
                    .frame(width: 56, height: 56)
            }
        }
        .onDisappear { request.cancel() }
        .task(id: Previews.shared.key(row, 230, scale: scale)) {
            let token = request.begin()
            let side: CGFloat = 230
            imageKey = Previews.shared.key(row, side, scale: scale)
            image = Previews.shared.cached(row, side: side, scale: scale)
            if image == nil {
                let candidate = await Previews.shared.load(row, side: side, scale: scale)
                guard !Task.isCancelled, request.accepts(token) else { return }
                image = candidate
            }
        }
    }
}

struct WeakerToggle: View {
    let count: Int
    let expanded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                Text(expanded ? "较弱匹配" : "\(count) 个较弱匹配")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// After a search: a big quiet symbol, what happened, what to try.
private struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Nothing typed yet: the app's mark (not a magnifier, which reads as a second search field), a pointer to the field
/// above, examples to click (each with the kind it finds), what's in the index, and the shortcut. A click anywhere else
/// puts the cursor in the field.
private struct SearchHome: View {
    let search: SearchModel
    let model: AppModel
    let engine: Engine
    @State private var kinds: [FileKind: Int] = [:]

    private static let examples: [(text: String, kind: ResultGroupKind)] = [
        ("报错信息的截图", .screenshots), ("付款收据", .documents), ("白板笔记", .images),
        ("有人笑的声音", .audio), ("海边的小狗", .video), ("预算相关的演示文稿", .documents),
    ]

    var body: some View {
        VStack(spacing: 0) {
            BrandMark()
            Text("记得内容，就能找到。")
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 18)
            Text("在上方输入你记得的内容：资料说了什么、画面或声音是什么，"
                 + "也可以直接输入关键词。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 440)
                .padding(.top, 6)
            Text("试着搜索")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
                .padding(.top, 26)
            FlowRow(spacing: 8) {
                ForEach(examples, id: \.text) { example in
                    ExampleChip(text: example.text, kind: example.kind) { search.query = example.text }
                }
            }
            .frame(maxWidth: 560)
            .padding(.top, 8)
            VStack(spacing: 8) {
                if !kinds.isEmpty {
                    HStack(spacing: 8) {
                        KindCounts(counts: kinds)
                        Text("位于 \(folders)")
                    }
                } else if model.status.searchable > 0 {
                    Text("\(folders) 中有 \(model.status.searchable.formatted()) 个文件可搜索")
                }
                if let hotkey = model.hotkey {
                    HStack(spacing: 6) {
                        Keycaps(caps: hotkey.caps, size: 10)
                        Text("在任何应用中打开知处")
                    }
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.top, 30)
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { search.focusField() }
        .task(id: "\(model.status.files)|\(search.folder ?? "*")") {
            let folder = search.folder
            var counts: [FileKind: Int] = [:]
            for summary in await engine.rootSummaries() where folder == nil || summary.path == folder {
                counts.merge(summary.kinds, uniquingKeysWith: +)
            }
            guard !Task.isCancelled else { return }
            if model.mail?.isAvailable == true, folder == nil || folder?.hasPrefix("mail:") == true {
                if let folder, folder.hasPrefix("mail:account:") {
                    let accountID = String(folder.dropFirst(13))
                    let config = model.settings.mail
                    counts[.mail] = model.mail.boxes.filter { $0.accountID == accountID && (config.mailboxIDs?.contains($0.id) ?? !$0.excludedByDefault) }.reduce(0) { $0 + $1.messagePaths.count }
                } else { counts[.mail] = model.mail.messages }
            }
            kinds = counts
        }
    }

    /// With code search on, one of code's too.
    private var examples: [(text: String, kind: ResultGroupKind)] {
        Self.examples + (model.hasCode ? [("code: 保存设置的代码", .code)] : [])
    }

    private var folders: String {
        let names = search.folder.map { [(model.mail?.scopeName($0) ?? SearchFolders.name($0))] }
            ?? (model.settings.roots.map(\.lastPathComponent) + (model.mail?.isAvailable == true ? model.mail.activeAccounts.map(\.name) : []))
        if names.isEmpty { return "已选择的来源" }
        return names.count <= 3 ? names.formatted(.list(type: .and)) : "\(names.count) 个来源"
    }
}

/// The app's icon with its own glow (the find in the D) spread soft around it: the window's empty states.
private struct BrandMark: View {
    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: 84, height: 84)
            .accessibilityHidden(true)
    }
}

/// An example query: the kind it finds, the words; a click searches for it.
private struct ExampleChip: View {
    let text: String
    let kind: ResultGroupKind
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Brand.leaf)
                Text(text)
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(Brand.leaf.opacity(hovering ? 0.2 : 0.1)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("搜索“\(text)”")
        .onHover { inside in
            hovering = inside
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onDisappear { if hovering { NSCursor.pop() } }
    }
}

/// Lays children out in rows, wrapping like text.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, _ subviews: Subviews) -> [(items: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], width: CGFloat, height: CGFloat)] = []
        var current: (items: [Int], width: CGFloat, height: CGFloat) = ([], 0, 0)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.items.isEmpty {
                rows.append(current)
                current = ([index], size.width, size.height)
            } else {
                current = (current.items + [index], needed, max(current.height, size.height))
            }
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
