import AppKit
import DigUpKit
import Observation
import SwiftUI

/// Opt-in Apple Mail reader. Protected source access happens in the signed app, never the indexing helper.
@Observable final class MailController {
    struct Account: Identifiable { let id: String; let name: String }
    private(set) var boxes: [MailboxSource] = []
    private(set) var syncing = false
    private(set) var isAvailable = false
    private(set) var notice = "邮件搜索尚未开启"
    private(set) var problem: String?
    private(set) var messages = 0
    private(set) var attachments = 0
    private(set) var updateBlocker: String?
    @ObservationIgnored private unowned let app: AppController
    @ObservationIgnored private var scan: Task<AppleMailSource.SyncResult, Error>?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var generation = 0

    init(app: AppController) { self.app = app }
    var accounts: [Account] {
        var seen = Set<String>()
        return boxes.filter { seen.insert($0.accountID).inserted }.map { Account(id: $0.accountID, name: $0.account) }
    }
    var activeAccounts: [Account] {
        let config = app.model.settings.mail
        let selected = Set(boxes.filter { config.mailboxIDs?.contains($0.id) ?? !$0.excludedByDefault }.map(\.accountID))
        return accounts.filter { selected.contains($0.id) }
    }
    var scopeIDs: [String] { isAvailable ? ["mail:all"] + activeAccounts.map { "mail:account:" + $0.id } : [] }
    func scopeName(_ id: String?) -> String? {
        guard isAvailable else { return nil }
        guard let id else { return "所有来源" }
        if id == "mail:all" { return "所有邮件" }
        if id.hasPrefix("mail:account:") { return accounts.first { $0.id == String(id.dropFirst(13)) }?.name }
        return nil
    }
    func start() {
        if updateBlocker != nil, !isAvailable { restoreCachedSources() }
        if app.model.settings.mail.enabled { refresh() }
        // Mail's local storage is private and has no supported push API. Reconcile at most once a minute.
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func apply(_ configuration: MailConfiguration) {
        generation += 1
        let oldScan = scan
        scan?.cancel()
        syncing = false
        isAvailable = false
        app.engine.setMailSource(active: false, mailboxes: [], enabled: app.model.settings.mail.enabled)
        app.mailSourceChanged()
        if configuration.enabled {
            if updateBlocker != nil { restoreCachedSources() }
            refresh()
        }
        else {
            notice = "邮件搜索已关闭，邮件索引缓存已移除"
            boxes = []; problem = nil; messages = 0; attachments = 0
            let cache = app.model.settings.mailCache
            // Same serial actor as refresh kickoff: unlink only this app's dedicated cache, never Mail originals.
            let previous = cleanup
            cleanup = Task.detached(priority: .utility) {
                _ = await previous?.value
                _ = try? await oldScan?.value
                try? FileManager.default.removeItem(at: cache)
            }
        }
    }
    @ObservationIgnored private var cleanup: Task<Void, Never>?

    func setUpdateBlocker(_ reason: String?, refreshWhenAllowed: Bool = true) {
        guard reason != updateBlocker else { return }
        updateBlocker = reason
        if let reason {
            generation += 1
            scan?.cancel()
            syncing = false
            if !isAvailable { restoreCachedSources() }
            if app.model.settings.mail.enabled { notice = "邮件更新已暂停 · \(reason)" }
        } else if refreshWhenAllowed { refresh() }
    }

    private func restoreCachedSources() {
        let settings = app.model.settings
        guard settings.mail.enabled,
              let cached = try? AppleMailSource.cachedMailboxes(indexFile: settings.indexDirectory.appendingPathComponent(IndexStore.mainFile)),
              !cached.isEmpty else { return }
        boxes = cached
        isAvailable = true
        let ids = cached.filter { settings.mail.mailboxIDs?.contains($0.id) ?? !$0.excludedByDefault }.map(\.id)
        app.engine.setMailSource(active: true, mailboxes: ids, enabled: true)
        app.mailSourceChanged()
    }

    func refresh() {
        let settings = app.model.settings
        guard settings.mail.enabled, !syncing else { return }
        guard updateBlocker == nil else {
            notice = "邮件更新已暂停 · \(updateBlocker!)"
            return
        }
        syncing = true; problem = nil; notice = "正在读取选定邮箱…"
        generation += 1
        let current = generation
        let previous = scan
        let cleanup = cleanup
        let task = Task.detached(priority: .utility) {
            _ = try? await previous?.value
            _ = await cleanup?.value
            try Task.checkCancellation()
            return try AppleMailSource.sync(at: settings.mailRoot, to: settings.mailCache,
                configuration: settings.mail, shouldStop: { Task.isCancelled })
        }
        scan = task
        Task {
            do {
                let result = try await task.value
                guard current == generation, !task.isCancelled else { return }
                boxes = result.mailboxes
                messages = result.messages; attachments = result.attachments
                let sourceChanged = !isAvailable || result.changed
                isAvailable = true; syncing = false
                let ids = boxes.filter { settings.mail.mailboxIDs?.contains($0.id) ?? !$0.excludedByDefault }.map(\.id)
                if sourceChanged { app.engine.setMailSource(active: true, mailboxes: ids, enabled: true) }
                notice = "已读取 \(messages) 封邮件 · \(attachments) 个附件"
                if result.missing > 0 { notice += " · \(result.missing) 项尚未下载或超过大小限制" }
                if !result.problems.isEmpty { problem = "\(result.problems.count) 封邮件暂时无法读取，已保留上次可用内容。" }
                if sourceChanged { app.mailSourceChanged() }
            } catch {
                guard current == generation else { return }
                syncing = false; isAvailable = false
                notice = "邮件来源暂不可用"
                problem = error is CancellationError ? nil : "无法读取 Apple Mail 邮件库。请开启知处的完整磁盘访问权限，并确认邮件已下载到本机，然后重新检查。"
                app.engine.setMailSource(active: false, mailboxes: [], enabled: app.model.settings.mail.enabled)
                app.mailSourceChanged()
            }
        }
    }
    func permissions() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") { NSWorkspace.shared.open(url) }
    }
}

struct MailSettings: View {
    let app: AppController
    @State private var draft = MailConfiguration()
    @State private var custom = ""
    private var source: MailController? { app.model.mail }

    var body: some View {
        Form {
            if app.model.settings.mail.enabled {
                Section {
                    SourceIndexProgress(model: app.model, source: .mail) { app.engine.setPaused(!app.model.status.paused) }
                    Toggle(AppSettings.batteryTitle, isOn: Binding(
                        get: { !app.model.settings.indexOnBattery }, set: { app.setIndexOnBattery(!$0) }))
                    Text(AppSettings.batteryDetail).font(.caption).foregroundStyle(.secondary)
                } header: { Text("邮件索引进度") }
            }
            Section {
                Toggle("搜索 Apple Mail 邮件", isOn: Binding(get: { app.model.settings.mail.enabled }, set: {
                    draft.enabled = $0; app.applyMail(draft)
                }))
                Text("仅在你开启后读取本机邮件。知处不会连接邮箱服务器，也不会自动下载邮件或附件。")
                    .font(.callout).foregroundStyle(.secondary)
                if let source, app.model.settings.mail.enabled {
                    HStack {
                        Label(source.notice, systemImage: source.isAvailable ? "checkmark.shield" : "envelope")
                        Spacer()
                        if source.syncing { ProgressView().controlSize(.small) }
                        else { Button("重新检查") { source.refresh() }.disabled(source.updateBlocker != nil) }
                    }
                    if let problem = source.problem {
                        Text(problem).foregroundStyle(.secondary).font(.callout)
                    }
                    if !source.isAvailable {
                        Button("打开完整磁盘访问权限设置…") { source.permissions() }
                        Text("在“隐私与安全性 → 完整磁盘访问权限”中开启知处，必要时退出并重新打开知处。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: { Text("邮件来源") }
            if app.model.settings.mail.enabled {
                Section {
                    if let source, !source.boxes.isEmpty {
                        ForEach(source.accounts) { account in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Toggle("账号", isOn: Binding(get: {
                                        let boxes = source.boxes.filter { $0.accountID == account.id }
                                        return !boxes.isEmpty && boxes.allSatisfy(selected)
                                    }, set: { value in
                                        for box in source.boxes where box.accountID == account.id { select(box, value) }
                                    })).toggleStyle(.checkbox).labelsHidden().accessibilityLabel(account.name)
                                    TextField("", text: Binding(get: { draft.accountNames[account.id] ?? account.name }, set: { draft.accountNames[account.id] = $0 }))
                                        .textFieldStyle(.plain).labelsHidden().fontWeight(.medium)
                                        .accessibilityLabel("账号名称")
                                        .help("可修改这个账号在知处中的名称；应用后生效")
                                }
                                ForEach(source.boxes.filter { $0.accountID == account.id }) { box in
                                    Toggle(isOn: Binding(get: { selected(box) }, set: { select(box, $0) })) {
                                        HStack { Text(box.name); Spacer(); Text("\(box.messagePaths.count) 封").foregroundStyle(.secondary) }
                                    }.toggleStyle(.checkbox).padding(.leading, 20).accessibilityLabel(box.name + "，\(box.messagePaths.count) 封邮件")
                                }
                            }.padding(.vertical, 4)
                        }
                    } else { Text("授权并检查后，在这里选择账号与邮箱。") .foregroundStyle(.secondary) }
                } header: { Text("索引这些邮箱") } footer: {
                    Text("默认排除垃圾邮件、废纸篓与草稿；取消勾选后，相关邮件及附件会从知处的索引中移除。")
                }
                Section {
                    Picker("附件范围", selection: $draft.attachmentMode) {
                        Text("不索引附件").tag("none")
                        Text("常用文档与图片").tag("common")
                        Text("自定义类型").tag("custom")
                    }.onChange(of: draft.attachmentMode) { _, mode in
                        if mode == "common" { draft.attachmentExtensions = MailConfiguration().attachmentExtensions }
                    }
                    if draft.attachmentMode == "custom" {
                        TextField("例如 pdf, docx, pptx, png", text: $custom)
                    }
                    if draft.attachmentMode != "none" {
                        Text("\(draft.attachmentMode == "custom" ? custom : draft.attachmentExtensions.joined(separator: "、"))")
                            .font(.caption).foregroundStyle(.secondary)
                        Stepper("单个附件不超过 \(draft.maxAttachmentMB) MB", value: $draft.maxAttachmentMB, in: 1...100)
                    }
                    HStack {
                        Text("只读取已下载附件，附件命中会显示原邮件和对应页码。")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("应用并建立索引") {
                            if draft.attachmentMode == "custom" { draft.attachmentExtensions = IndexOptions.extensions(custom).sorted() }
                            app.applyMail(draft)
                        }.buttonStyle(.borderedProminent)
                    }
                } header: { Text("附件索引") }
            }
        }
        .formStyle(.grouped)
        .onAppear { draft = app.model.settings.mail; custom = draft.attachmentExtensions.joined(separator: ", ") }
    }
    private func selected(_ box: MailboxSource) -> Bool { draft.mailboxIDs?.contains(box.id) ?? !box.excludedByDefault }
    private func select(_ box: MailboxSource, _ value: Bool) {
        var ids = Set(draft.mailboxIDs ?? source?.boxes.filter { !$0.excludedByDefault }.map(\.id) ?? [])
        if value { ids.insert(box.id) } else { ids.remove(box.id) }
        draft.mailboxIDs = ids.sorted()
    }
}
