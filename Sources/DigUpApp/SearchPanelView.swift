import AppKit
import DigUpKit
import SwiftUI

struct SearchPanelView: View {
    @Bindable var controller: SearchPanelController

    var body: some View {
        VStack(spacing: 0) {
            header
            if controller.phase != .empty {
                Divider()
                content
                    .frame(maxHeight: .infinity)
                Divider()
                footer
            }
        }
        .frame(width: SearchPanelController.width)
        .frame(maxHeight: .infinity, alignment: .top)
        // Glass alone is too see-through over busy backgrounds.
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: SearchPanelController.cornerRadius, style: .continuous))
        .onChange(of: controller.model.status.activity) { _, activity in
            if activity == .idle { controller.indexChanged() }
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            // A search of code shows it: the field's magnifier becomes code's mark.
            Image(systemName: controller.isCode ? FileKind.code.symbol : "magnifyingglass")
                .font(.system(size: controller.isCode ? 17 : 20, weight: .semibold))
                .foregroundStyle(Brand.iconAccent)
                .frame(width: 24)
                .help(controller.isCode ? "正在搜索代码" : "")
            // With code search on, one example is code's: nothing else in the panel shows "code:".
            SearchField(text: $controller.query, fontSize: 22,
                        placeholder: controller.model.hasCode
                            ? "描述你记得的内容，也可输入 code: 搜索代码…"
                            : "描述你记得的内容，例如“付款失败的截图”…") {
                controller.field = $0
            }
            if controller.phase == .words, controller.encoder == .starting {
                ProgressView().controlSize(.small)
            }
            SearchScopePicker(folder: controller.folder, roots: controller.scopeRoots, compact: true,
                              mail: controller.isCode ? nil : controller.model.mail,
                              select: { controller.selectFolder($0) }, manage: { controller.manageScopeFolders() })
                .frame(width: 164, height: 30)
            if let activity = controller.model.activityBadge {
                Text(activity)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.07)))
                    .help(controller.model.statusLine)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: SearchPanelController.fieldHeight)
    }

    @ViewBuilder private var content: some View {
        if controller.phase == .codeHint || controller.phase == .codeOff {
            CodeHint(controller: controller)
        } else if controller.results.isEmpty {
            VStack(spacing: 8) {
                if controller.phase == .words {
                    Text("正在搜索…").foregroundStyle(.secondary)
                } else if !controller.model.hasFolders {
                    Text("尚未选择文件夹").font(.system(size: 15, weight: .semibold))
                    Text("知处只搜索你选择的文件夹。").foregroundStyle(.secondary)
                    Button("选择文件夹…") { controller.chooseFolders() }
                        .padding(.top, 4)
                } else if controller.isCode {
                    Text("代码中没有合适的结果").font(.system(size: 15, weight: .semibold))
                    Text("试试描述代码的作用，或输入代码中的名称。").foregroundStyle(.secondary)
                } else {
                    Text(controller.folder.map { "在 \((controller.model.mail?.scopeName($0) ?? SearchFolders.name($0))) 中未找到合适的结果" } ?? "没有找到合适的结果")
                        .font(.system(size: 15, weight: .semibold))
                    Text("试试描述画面、声音，或输入记得的词语。")
                        .foregroundStyle(.secondary)
                }
                if controller.folder != nil, controller.phase != .words {
                    Button(controller.model.mail?.isAvailable == true ? "搜索所有来源" : "搜索所有文件夹") { controller.selectFolder(nil) }.padding(.top, 4)
                }
            }
            .font(.system(size: 13))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                ResultList(controller: controller)
                    .frame(width: SearchPanelController.listWidth)
                Divider()
                Group {
                    if let row = controller.selectedRow, row.isMail {
                        MailReaderPane(row: row, open: { controller.openSelected() }).padding(-16)
                    } else if let row = controller.selectedRow {
                        VStack(alignment: .leading, spacing: 10) {
                            PreviewPane(row: row, imageSize: CGSize(width: 410, height: 214),
                                        open: { controller.openSelected() })
                            PreviewActions(row: row, open: { controller.openSelected() },
                                           reveal: { controller.revealSelected() }, controlSize: .small)
                        }
                    } else if controller.selection == SearchPanelController.weakerToggle {
                        WeakerExplainer(count: controller.results.weaker.count, expanded: controller.showWeaker)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text([controller.folder.map { "\((controller.model.mail?.scopeName($0) ?? SearchFolders.name($0))) 内" }, statusText].compactMap { $0 }.joined(separator: " · "))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(keysText)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 16)
        .frame(height: 30)
    }

    /// The keys, saying where ↩ and Space go for a page or moment: "↩ Open at 0:06   ␣ Quick Look at 0:06", and for
    /// code, at which line: "↩ Open in Zed at line 12".
    private var keysText: String {
        let row = controller.selectedRow
        if let row, row.isMail { return "↩ 打开原邮件   ␣ 快速查看\(row.jump.map { "（\($0)）" } ?? "")   ⌘C 复制邮件链接" }
        if let row, row.kind == .code {
            let line = row.segment == .lines ? "（第 \(row.codeLine) 行）" : ""
            return "↩ \(row.openTitle)\(line)   ⌘↩ 在 Finder 中显示   ␣ 快速查看   ⌘C 复制"
        }
        let place = row?.jump.map { "（\($0)）" } ?? ""
        return "↩ \(row?.openTitle ?? "打开")   ⌘↩ 在 Finder 中显示   ␣ 快速查看\(place)   ⌘C 复制"
    }

    private var statusText: String {
        if let note = controller.note { return note }
        if let notice = controller.scopeNotice { return notice }
        switch controller.phase {
        case .words:
            return controller.encoder == .starting ? "正在匹配关键词，语义搜索正在准备…" : "正在匹配关键词…"
        case .wordsOnly:
            return controller.model.meaningUnavailable ?? "当前仅匹配关键词，语义搜索暂不可用"
        case .codeHint, .codeOff:
            return controller.phase == .codeOff ? "代码搜索尚未开启" : "正在搜索代码"
        case .meaning, .empty:
            if controller.isCode, let indexing = controller.model.status.code.indexing, indexing.total > 0 {
                return "正在读取代码（\(Int(Double(indexing.done) / Double(indexing.total) * 100))%），部分内容尚不可搜索"
            }
            if !controller.isCode, let caveat = controller.model.resultsCaveat { return caveat }
            let count = controller.results.strongRows.count
            let weaker = controller.results.weaker.count
            return (count == 1 ? "1 个结果" : "\(count) 个结果") + (controller.isCode ? "（代码）" : "")
                + (weaker > 0 ? " · \(weaker) 个较弱匹配" : "")
        }
    }
}

private struct ResultList: View {
    let controller: SearchPanelController

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(controller.results.groups) { group in
                        GroupHeader(title: group.kind.title)
                        ForEach(group.rows) { row in
                            PanelRow(row: row, selected: row.id == controller.selection)
                                .id(row.id)
                                .overlay(FileDragArea(url: row.url, openTitle: row.openTitle,
                                                      onClick: { controller.select(row) },
                                                      onOpen: {
                                                          controller.select(row)
                                                          controller.openSelected()
                                                      }))
                        }
                        if group.total > group.rows.count {
                            Button {
                                controller.openInWindow(group.kind)
                            } label: {
                                Text("查看全部 \(group.total) 个\(group.kind.title)…")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                            .help("在知处窗口中查看这些结果（⌘O 查看全部）")
                        }
                    }
                    if !controller.results.weaker.isEmpty {
                        WeakerRow(count: controller.results.weaker.count, expanded: controller.showWeaker,
                                  selected: controller.selection == SearchPanelController.weakerToggle)
                            .id(SearchPanelController.weakerToggle)
                            .onTapGesture { controller.toggleWeaker() }
                            .padding(.top, 6)
                        if controller.showWeaker {
                            ForEach(controller.results.weaker) { row in
                                PanelRow(row: row, selected: row.id == controller.selection)
                                    .id(row.id)
                                    .opacity(0.85)
                                    .overlay(FileDragArea(url: row.url, openTitle: row.openTitle,
                                                          onClick: { controller.select(row) },
                                                          onOpen: {
                                                              controller.select(row)
                                                              controller.openSelected()
                                                          }))
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .onChange(of: controller.selection) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }
}

struct GroupHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A result in the panel's list: thumbnail, name with the page or moment, and the matched words (or the folder).
private struct PanelRow: View {
    let row: ResultRow
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Code's thumbnail would be a page of tiny text: its file type's icon says more.
            if row.isMail {
                Image(systemName: "envelope").foregroundStyle(Brand.iconAccent).font(.system(size: 22)).frame(width: 36, height: 36)
            } else { ThumbnailView(url: row.url, version: row.previewKey, side: 36, iconOnly: row.kind == .code) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let place = row.place { PlaceBadge(text: place) }
                }
                if row.isMail {
                    Text(row.info["mail_sender"] ?? "").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    if row.mailAttachment != nil { Text(row.reason).font(.system(size: 10)).foregroundStyle(Brand.iconAccent).lineLimit(1) }
                } else if let excerpt = row.excerpt, row.matchedWords, row.kind != .code {
                    Text(highlighted(excerpt, size: 11))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(row.folder)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.24) : Color.clear))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.kind.title), \(row.name), \(row.reason)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "▸ 14 weaker matches", selectable with the arrows like a result; ↩ or a click unfolds them.
private struct WeakerRow: View {
    let count: Int
    let expanded: Bool
    let selected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9.5, weight: .bold))
                .rotationEffect(.degrees(expanded ? 90 : 0))
            Text(expanded ? "较弱匹配" : "\(count) 个较弱匹配")
                .font(.system(size: 11.5, weight: .medium))
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.24) : Color.clear))
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
    }
}

private struct WeakerExplainer: View {
    let count: Int
    let expanded: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text(expanded ? "较弱匹配" : "\(count) 个较弱匹配")
                .font(.system(size: 14, weight: .semibold))
            Text("这些结果的相关度低于上方结果。按回车键" + (expanded ? "收起。" : "展开。"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ThumbnailView: View {
    static let side: CGFloat = 36
    let url: URL
    var version: String = ""
    var side: CGFloat = ThumbnailView.side
    /// The file type's icon, not a picture of the file.
    var iconOnly = false
    @State private var image: NSImage?
    @State private var imageKey: NSString?
    @State private var request = PreviewRequestGate()
    @Environment(\.displayScale) private var scale

    var body: some View {
        ZStack {
            if let image, imageKey == Thumbnails.shared.key(url, side: side, scale: scale) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side > 60 ? 8 : 6, style: .continuous))
        .onDisappear { request.cancel() }
        .task(id: "\(version)|\(Thumbnails.shared.key(url, side: side, scale: scale))|\(iconOnly)") {
            let token = request.begin()
            image = nil
            guard !iconOnly else { return }
            imageKey = Thumbnails.shared.key(url, side: side, scale: scale)
            image = Thumbnails.shared.cached(url, side: side, scale: scale)
            if image == nil {
                let candidate = await Thumbnails.shared.load(url, side: side, scale: scale)
                guard !Task.isCancelled, request.accepts(token) else { return }
                image = candidate
            }
        }
    }
}

/// The search field. AppKit, so the panel and the window can focus it and see its text selection (for ⌘C) directly;
/// the arrows, ↩ and Esc never reach it, because their key monitors take those first.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 22
    let placeholder: String
    var onMake: (NSTextField) -> Void = { _ in }
    /// The field got the cursor (true) or lost it (false).
    var onFocus: (Bool) -> Void = { _ in }

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusReportingField()
        field.onFocus = onFocus
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: fontSize)
        field.placeholderString = placeholder
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.delegate = context.coordinator
        field.setAccessibilityLabel("搜索")
        onMake(field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        (field as? FocusReportingField)?.onFocus = onFocus
        // While an input method composes (Korean, Japanese, Chinese), the field is ahead of `text` until the syllable
        // is committed, and writing `text` back would cut the composition short ("사어ㅂ" typed for "사업").
        if (field.currentEditor() as? NSTextView)?.hasMarkedText() != true, field.stringValue != text {
            field.stringValue = text
        }
        if field.placeholderString != placeholder { field.placeholderString = placeholder }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

/// A text field that says when it gets the cursor and when it gives it up (its editing ends).
final class FocusReportingField: NSTextField {
    var onFocus: (Bool) -> Void = { _ in }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became { onFocus(true) }
        return became
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        onFocus(false)
    }
}

/// Click to select, double-click to open, drag to copy the file into Finder, Mail, a chat… (an AppKit dragging
/// source, `FileDragView`).
struct FileDragArea: NSViewRepresentable {
    let url: URL
    /// "Open at 0:06": what double-click and the menu's first item do.
    var openTitle = "打开"
    let onClick: () -> Void
    let onOpen: () -> Void

    func makeNSView(context: Context) -> FileDragView { FileDragView() }

    func updateNSView(_ view: FileDragView, context: Context) {
        view.url = url
        view.openTitle = openTitle
        view.onClick = onClick
        view.onOpen = onOpen
    }
}

final class FileDragView: NSView, NSDraggingSource {
    var url: URL?
    var openTitle = "打开"
    var onClick: () -> Void = {}
    var onOpen: () -> Void = {}
    private var mouseDownEvent: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            mouseDownEvent = nil
            onOpen()
        } else {
            mouseDownEvent = event
            onClick()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDownEvent, let url else { return }
        let dx = event.locationInWindow.x - down.locationInWindow.x
        let dy = event.locationInWindow.y - down.locationInWindow.y
        guard dx * dx + dy * dy > 9 else { return }
        mouseDownEvent = nil
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let point = convert(down.locationInWindow, from: nil)
        let side: CGFloat = 44
        let image = Thumbnails.shared.cached(url, side: ThumbnailView.side, scale: window?.backingScaleFactor ?? 1) ?? NSWorkspace.shared.icon(forFile: url.path)
        item.setDraggingFrame(NSRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side),
                              contents: image)
        beginDraggingSession(with: [item], event: down, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
    }

    /// Right-click: select it, and offer what you'd do with a file.
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let url else { return nil }
        onClick()
        let menu = NSMenu()
        menu.addItem(ActionMenuItem(openTitle) { [onOpen] in onOpen() })
        menu.addItem(ActionMenuItem("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([url]) })
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("复制") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
        })
        menu.addItem(ActionMenuItem("复制路径") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        })
        return menu
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Copy, never move: dropping a result into a Finder folder must not take it away from where it lives.
        context == .outsideApplication ? [.copy, .generic] : []
    }
}

/// "code:" typed: what to type after it, or (without code folders) how to turn code search on.
private struct CodeHint: View {
    let controller: SearchPanelController

    static let examples = ["code: 带退避的请求重试", "code: 保存设置的代码",
                           "code: 解析命令行选项"]

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: FileKind.code.symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Brand.gradient)
            if controller.phase == .codeOff {
                Text("代码搜索尚未开启").font(.system(size: 15, weight: .semibold))
                Text("知处可按作用搜索选定文件夹中的代码，使用独立索引，"
                     + "不会混入其他搜索结果。")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Button("选择代码文件夹…") { controller.setUpCodeSearch() }
                    .padding(.top, 4)
            } else {
                Text("搜索你的代码").font(.system(size: 15, weight: .semibold))
                Text("描述代码的作用，或输入代码中的名称。").foregroundStyle(.secondary)
                VStack(spacing: 6) {
                    ForEach(Self.examples, id: \.self) { example in
                        Button { controller.tryExample(example) } label: {
                            Text(example)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Brand.leaf.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)
            }
        }
        .font(.system(size: 13))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
