import AppKit
import DigUpKit
import SwiftUI

/// Reader uses normalized text: no remote images, tracking pixels, scripts or network requests.
struct MailPreview: View {
    let row: ResultRow
    let size: CGSize
    @State private var mail: CachedMail?
    @State private var showsAttachment = true
    @State private var problem: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(row.title).font(.system(size: 19, weight: .semibold)).textSelection(.enabled)
                Text("发件人：" + (row.info["mail_sender"] ?? ""))
                Text("收件人：" + (row.info["mail_to"] ?? ""))
                    .lineLimit(2).foregroundStyle(.secondary)
                HStack {
                    Text(row.mailDate.formatted(date: .abbreviated, time: .shortened))
                    Spacer()
                    Text(row.folder).lineLimit(1).truncationMode(.middle)
                }.font(.caption).foregroundStyle(.secondary)
            }.font(.system(size: 12))
            Divider()
            if let attachment = row.mailAttachment {
                Picker("预览内容", selection: $showsAttachment) {
                    Text("正文").tag(false)
                    Text(attachment).tag(true)
                }.pickerStyle(.segmented)
            }
            if row.mailAttachment != nil, showsAttachment {
                PreviewPicture(row: row, size: CGSize(width: size.width, height: max(180, size.height - 100)), open: {
                    NSWorkspace.shared.open(row.url)
                })
                Text(row.reason).font(.system(size: 12, weight: .medium)).foregroundStyle(Brand.iconAccent)
            } else if let mail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if mail.bodyUnavailable {
                            Label("正文已加密或尚未下载，请在原邮件中查看。", systemImage: "lock")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(mail.body.isEmpty ? "此邮件暂无可读取的正文。" : String(mail.body.prefix(100_000)))
                                .font(.system(size: 13)).lineSpacing(6).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if mail.body.count > 100_000 { Text("正文较长，此处显示前 10 万字；完整内容仍参与搜索，可打开原邮件查看。").font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 4)
                }.frame(maxHeight: max(160, size.height - 150))
            } else if let problem { Text(problem).foregroundStyle(.secondary) }
            else { ProgressView().controlSize(.small) }
            if let mail, !mail.attachments.isEmpty {
                Divider()
                ForEach(mail.attachments, id: \.cachedName) { attachment in
                    Button {
                        if let parent = row.info["mail_parent"] {
                            let url = URL(fileURLWithPath: parent).deletingLastPathComponent().appendingPathComponent(attachment.cachedName)
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "paperclip").foregroundStyle(Brand.iconAccent)
                            Text(attachment.name).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.bytes), countStyle: .file))
                                .foregroundStyle(.secondary).font(.caption)
                            Image(systemName: "arrow.up.right")
                        }
                    }.buttonStyle(.plain)
                }
            }
            if let mail, mail.missingAttachments > 0 {
                Text("\(mail.missingAttachments) 个附件尚未下载或超过索引大小限制，可在原邮件中查看。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .task(id: row.previewKey) {
            mail = nil; problem = nil; showsAttachment = true
            guard let path = row.info["mail_parent"] else { problem = "暂时无法读取邮件预览。"; return }
            let value = await Task.detached(priority: .userInitiated) { try? CachedMail.read(URL(fileURLWithPath: path)) }.value
            guard !Task.isCancelled else { return }
            mail = value
            if value == nil { problem = "本机邮件缓存已更新，请重新搜索。" }
        }
    }
}

enum MailActions {
    static func openOriginal(_ row: ResultRow) {
        guard !Opener.dryRun else { log("mail: open original (dry run)"); return }
        if let link = row.mailLink, NSWorkspace.shared.urlForApplication(toOpen: link) != nil {
            NSWorkspace.shared.open(link)
        } else if let path = row.info["mail_original"] {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }
    static func copyLink(_ row: ResultRow, to pasteboard: NSPasteboard = .general) {
        guard let link = row.mailLink else { return }
        pasteboard.clearContents(); pasteboard.setString(link.absoluteString, forType: .string)
    }
}

struct MailResultsList: View {
    @Bindable var search: SearchModel
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(search.results.ranked) { row in item(row) }
                    if !search.results.weaker.isEmpty {
                        Button {
                            search.showWeaker.toggle()
                        } label: {
                            Label("\(search.results.weaker.count) 个较弱匹配", systemImage: search.showWeaker ? "chevron.down" : "chevron.right")
                        }.buttonStyle(.plain).foregroundStyle(.secondary).padding(10)
                        if search.showWeaker { ForEach(search.results.weaker) { row in item(row) } }
                    }
                }.padding(12)
            }.onChange(of: search.selection) { _, id in if let id { proxy.scrollTo(id) } }
        }.onAppear { search.columns = 1 }
    }
    private func item(_ row: ResultRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "envelope").font(.system(size: 18)).foregroundStyle(Brand.iconAccent)
                .frame(width: 32, height: 32).background(Brand.iconAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(row.title).fontWeight(.semibold).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(row.mailDate.formatted(date: .numeric, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                }
                Text(row.info["mail_sender"] ?? "").font(.system(size: 12)).lineLimit(1).foregroundStyle(.secondary)
                if let excerpt = row.excerpt {
                    Text(highlighted(excerpt, size: 12)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                }
                if row.mailAttachment != nil { Label(row.reason, systemImage: "paperclip").font(.caption).foregroundStyle(Brand.iconAccent) }
                Text(row.folder).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(search.selectedRow?.id == row.id ? Color.accentColor.opacity(0.24) : Color.clear))
        .contentShape(Rectangle()).onTapGesture { search.select(row) }
        .onTapGesture(count: 2) { search.open(row) }.id(row.id)
    }
}

/// Keep primary actions visible while long messages and attachments scroll independently above them.
struct MailReaderPane: View {
    let row: ResultRow
    let open: () -> Void
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    MailPreview(row: row, size: CGSize(width: max(240, geometry.size.width - 32),
                        height: max(260, geometry.size.height - 130)))
                        .padding(16)
                }
                Divider()
                HStack {
                    Button("打开原邮件", action: open).buttonStyle(.borderedProminent)
                    if row.mailAttachment != nil { Button("打开附件") { NSWorkspace.shared.open(row.url) } }
                    else { Button("复制邮件链接") { MailActions.copyLink(row) }.disabled(row.mailLink == nil) }
                }.padding(16)
            }
        }
    }
}
