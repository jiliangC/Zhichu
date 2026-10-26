import Foundation
import MimeFoundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

public struct MailConfiguration: Codable, Equatable, Sendable {
    public var enabled = false
    /// Nil selects the safe default mailboxes. Empty explicitly selects none.
    public var mailboxIDs: [String]?
    public var attachmentMode = "common"
    public var attachmentExtensions = ["pdf", "doc", "docx", "xlsx", "pptx", "txt", "rtf", "png", "jpg", "jpeg", "heic"]
    public var maxAttachmentMB = 50
    public var accountNames: [String: String] = [:]
    public init() {}
}

public struct MailboxSource: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let accountID: String
    public var account: String
    public let name: String
    public let path: String
    public let messagePaths: [String]
    public var excludedByDefault: Bool {
        ["junk", "spam", "trash", "deleted", "draft", "垃圾", "废纸", "廢紙", "已删除", "已刪除", "草稿"].contains { name.lowercased().contains($0) }
    }
}

public struct MailAttachment: Codable, Equatable, Sendable {
    public var name: String
    public var cachedName: String
    public var bytes: Int
    public var part: String
}

public struct CachedMail: Codable, Equatable, Sendable {
    public var id: String
    public var subject: String
    public var sender: String
    public var recipients: String
    public var date: Double
    public var messageID: String
    public var accountID: String
    public var account: String
    public var mailboxID: String
    public var mailbox: String
    public var originalPath: String
    public var body: String
    public var attachments: [MailAttachment]
    public var missingAttachments: Int
    public var bodyUnavailable: Bool
    public var sourceVersion: String? = nil

    public var searchText: String { "主题：\(subject)\n发件人：\(sender)\n收件人：\(recipients)\n\n\(body)" }
    public static let fileName = "message.zhmail"
    public static func read(_ url: URL) throws -> CachedMail {
        try JSONDecoder().decode(CachedMail.self, from: Data(contentsOf: url))
    }
    public static func context(for url: URL) -> CachedMail? {
        try? read(url.deletingLastPathComponent().appendingPathComponent(fileName))
    }
    public func info(for url: URL) -> [String: String] {
        var result = ["mail_id": id, "mail_subject": subject, "mail_sender": sender, "mail_to": recipients,
                      "mail_date": String(date), "mail_message_id": messageID, "mail_account_id": accountID,
                      "mail_account": account, "mail_mailbox_id": mailboxID, "mail_mailbox": mailbox,
                      "mail_original": originalPath, "mail_parent": url.deletingLastPathComponent().appendingPathComponent(Self.fileName).path,
                      "mail_missing": String(missingAttachments), "mail_body_unavailable": bodyUnavailable ? "1" : "0"]
        if url.lastPathComponent != Self.fileName {
            result["mail_attachment"] = attachments.first { $0.cachedName == url.lastPathComponent }?.name ?? url.lastPathComponent
        }
        return result
    }
}

public enum MailSourceError: Error, LocalizedError {
    case unavailable, invalidMessage, tooLarge, encrypted
    public var errorDescription: String? {
        switch self {
        case .unavailable: "无法读取 Apple Mail 邮件库。请检查完整磁盘访问权限，或确认本机已配置 Mail。"
        case .invalidMessage: "邮件格式无效或内容尚未完整下载。"
        case .tooLarge: "邮件超过本次读取上限。"
        case .encrypted: "此邮件正文已加密，暂时无法索引。"
        }
    }
}

/// A dedicated, read-only Apple Mail adapter. Never traverses protected Mail data through the general crawler.
public enum AppleMailSource {
    public static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func identifier(_ path: String) -> String { digest(Data(path.utf8)) }

    /// On a battery-only launch, restore searchable sources from our own index without traversing Mail.
    public static func cachedMailboxes(indexFile: URL) throws -> [MailboxSource] {
        let db = try Database(path: indexFile.path, readOnly: true)
        var boxes: [MailboxSource] = []
        try db.query("""
            SELECT json_extract(info, '$.mail_mailbox_id'), json_extract(info, '$.mail_account_id'),
                   max(json_extract(info, '$.mail_account')), max(json_extract(info, '$.mail_mailbox')), count(*)
            FROM files WHERE kind = 'mail' AND json_valid(info)
              AND json_extract(info, '$.mail_mailbox_id') IS NOT NULL
            GROUP BY json_extract(info, '$.mail_mailbox_id'), json_extract(info, '$.mail_account_id')
            ORDER BY 2, 4
            """) { row in
            guard let id = row.text(0), let accountID = row.text(1) else { return }
            // Cached counts only; paths are intentionally absent and never used to read protected originals.
            boxes.append(MailboxSource(id: id, accountID: accountID, account: row.text(2) ?? "邮箱",
                                       name: row.text(3) ?? "邮箱", path: "",
                                       messagePaths: Array(repeating: "", count: Int(row.int(4)))))
        }
        return boxes
    }

    public static func discover(at root: URL, shouldStop: () -> Bool = { false }) throws -> [MailboxSource] {
        let fm = FileManager.default
        let children = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])
        let versions = children.filter { $0.lastPathComponent.range(of: #"^V\d+$"#, options: .regularExpression) != nil }
        let base = versions.max { (Int($0.lastPathComponent.dropFirst()) ?? 0) < (Int($1.lastPathComponent.dropFirst()) ?? 0) } ?? root
        var scanError: Error?
        guard let walker = fm.enumerator(at: base, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles],
                                         errorHandler: { _, error in scanError = error; return false }) else { throw MailSourceError.unavailable }
        var boxes: [String: [String]] = [:]
        for case let url as URL in walker {
            if shouldStop() { throw CancellationError() }
            let name = url.lastPathComponent
            if ["MailData", "Attachments", "Signatures"].contains(name) { walker.skipDescendants(); continue }
            if url.pathExtension == "mbox" { boxes[url.path, default: []] = boxes[url.path] ?? []; continue }
            guard ["emlx", "eml"].contains(url.pathExtension.lowercased()) else { continue }
            var parent = url.deletingLastPathComponent()
            while parent.path.hasPrefix(base.path + "/"), parent.pathExtension != "mbox" { parent.deleteLastPathComponent() }
            if parent.pathExtension == "mbox" { boxes[parent.path, default: []].append(url.path) }
        }
        if let scanError { throw scanError } // Never prune from a partial or denied walk.
        let accountIDs = Set(boxes.keys.map { String($0.dropFirst(base.path.count + 1).split(separator: "/").first ?? "local") })
        let accountNames = MailAccountNames.load(mailRoot: root, accountIDs: accountIDs)
        return boxes.map { path, files in
            let relative = path.dropFirst(base.path.count + 1).split(separator: "/")
            let accountID = String(relative.first ?? "local")
            var name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent.removingPercentEncoding ?? "邮箱"
            switch name.lowercased() {
            case "inbox": name = "收件箱"
            case "outbox": name = "发件箱"
            case "sendlater", "send later": name = "稍后发送"
            case "sent messages", "sent", "sent items": name = "已发送"
            case "archive": name = "归档"
            case "trash", "deleted messages": name = "废纸篓"
            case "junk", "spam": name = "垃圾邮件"
            case "drafts": name = "草稿"
            default: break
            }
            return MailboxSource(id: identifier(path), accountID: accountID,
                                 account: accountID == "Mailboxes" ? "我的 Mac" : accountNames[accountID.lowercased()] ?? "邮箱 \(accountID.prefix(8))",
                                 name: name, path: path, messagePaths: files.sorted())
        }.sorted { ($0.accountID, $0.name) < ($1.accountID, $1.name) }
    }

    public struct Parsed: Sendable {
        public var subject: String, sender: String, recipients: String, messageID: String, body: String
        public var date: Double
        public var unavailable: Bool
        public var parts: [Part]
    }
    public struct Part: Sendable { public var name: String, number: String; public var data: Data }

    public static func parse(_ data: Data, emlx: Bool) throws -> Parsed {
        guard data.count <= 150 * 1024 * 1024 else { throw MailSourceError.tooLarge }
        let raw: Data
        if emlx {
            guard let end = data.firstIndex(of: 10), end < 32,
                  let count = Int(String(decoding: data[..<end], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)),
                  count > 0, count <= data.count - end - 1 else { throw MailSourceError.invalidMessage }
            raw = Data(data[(end + 1)..<(end + 1 + count)])
        } else { raw = data }
        var options = ParserOptions()
        options.maxMimeDepth = 32
        let message = try MimeMessage.load(options, MemoryStream(Array(raw)))
        let encrypted = message.body?.contentType.mimeType.lowercased() == "application/pkcs7-mime"
            || message.body?.contentType.mimeType.lowercased() == "multipart/encrypted"
        let body = encrypted ? "" : (message.textBody ?? message.htmlBody.map { DocExtractor.plainText(fromHTML: $0) } ?? "")
        var parts: [Part] = []
        func walk(_ entity: MimeEntity, number: String, depth: Int) throws {
            guard depth < 32, parts.count < 200 else { return }
            if let multipart = entity as? Multipart {
                for (i, child) in multipart.enumerated() {
                    try walk(child, number: number.isEmpty ? String(i + 1) : number + ".\(i + 1)", depth: depth + 1)
                }
            } else if let part = entity as? MimePart, let filename = part.fileName, !filename.isEmpty {
                let output = MemoryStream()
                try part.content?.decodeTo(output)
                parts.append(Part(name: filename, number: number.isEmpty ? "1" : number, data: Data(output.toByteArray())))
            }
        }
        if !encrypted, let root = message.body { try walk(root, number: "", depth: 0) }
        return Parsed(subject: message.subject?.isEmpty == false ? message.subject! : "（无主题）",
                      sender: message.from.description, recipients: message.to.description,
                      messageID: message.messageId ?? "", body: String(body.prefix(8_000_000)),
                      date: message.date?.date.timeIntervalSince1970 ?? 0,
                      unavailable: encrypted || body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, parts: parts)
    }

    public struct SyncResult: Sendable {
        public var messages = 0, attachments = 0, missing = 0
        public var changed = false
        public var problems: [String] = []
        public var mailboxes: [MailboxSource] = []
        public init() {}
    }

    /// Materializes selected messages into a private cache consumed by the existing index helper.
    /// Original messages and Mail's database are never written. All output paths are controlled by this adapter.
    public static func sync(at root: URL, to cache: URL, configuration: MailConfiguration,
                            shouldStop: () -> Bool = { false }) throws -> SyncResult {
        guard configuration.enabled else { return SyncResult() }
        let boxes = try discover(at: root, shouldStop: shouldStop).map { source in
            var source = source
            if let name = configuration.accountNames[source.accountID], !name.isEmpty { source.account = name }
            return source
        }
        let selected = boxes.filter { configuration.mailboxIDs?.contains($0.id) ?? !$0.excludedByDefault }
        let fm = FileManager.default
        try fm.createDirectory(at: cache, withIntermediateDirectories: true)
        #if !os(Windows)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: cache.path)
        #endif
        var result = SyncResult()
        result.mailboxes = boxes
        var seen = Set<String>()
        var complete = true
        for box in selected {
            for path in box.messagePaths {
                if shouldStop() { complete = false; break }
                let id = identifier(path)
                seen.insert(id)
                let directory = cache.appendingPathComponent(id)
                do {
                    guard let stat = FileSystem.info(of: path), stat.isRegular, !stat.dataless else { result.missing += 1; continue }
                    guard stat.size <= 150 * 1024 * 1024 else { throw MailSourceError.tooLarge }
                    let original = URL(fileURLWithPath: path)
                    let version = "v2|\(stat.size)|\(stat.mtime)|\(configuration.attachmentMode)|\(configuration.attachmentExtensions.sorted())|\(configuration.maxAttachmentMB)|\(box.account)"
                    if !original.lastPathComponent.contains(".partial."),
                       let old = try? CachedMail.read(directory.appendingPathComponent(CachedMail.fileName)),
                       old.sourceVersion == version,
                       old.attachments.allSatisfy({ FileSystem.info(of: directory.appendingPathComponent($0.cachedName).path)?.size == Int64($0.bytes) }) {
                        result.messages += 1; result.attachments += old.attachments.count; result.missing += old.missingAttachments
                        continue
                    }
                    let parsed = try parse(Data(contentsOf: original), emlx: original.pathExtension.lowercased() == "emlx")
                    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
                    var attachments: [MailAttachment] = [], missing = 0
                    for (index, part) in parsed.parts.enumerated() {
                        let name = URL(fileURLWithPath: part.name.replacingOccurrences(of: "\\", with: "/")).lastPathComponent
                        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
                        guard configuration.attachmentMode != "none", configuration.attachmentExtensions.contains(ext) else { continue }
                        var bytes = part.data
                        if bytes.isEmpty {
                            let stem = original.lastPathComponent.components(separatedBy: ".").first ?? ""
                            let external = original.deletingLastPathComponent().deletingLastPathComponent()
                                .appendingPathComponent("Attachments").appendingPathComponent(stem)
                                .appendingPathComponent(part.number).appendingPathComponent(name)
                            let real = external.resolvingSymlinksInPath().path
                            if FolderSelection.isInside(real, URL(fileURLWithPath: box.path).resolvingSymlinksInPath().path),
                               let info = FileSystem.info(of: real), !info.dataless, info.size <= Int64(configuration.maxAttachmentMB) * 1024 * 1024 {
                                bytes = (try? Data(contentsOf: URL(fileURLWithPath: real))) ?? Data()
                            }
                        }
                        guard !bytes.isEmpty, bytes.count <= max(1, configuration.maxAttachmentMB) * 1024 * 1024 else { missing += 1; continue }
                        let cachedName = "\(index + 1)-\(name)"
                        let destination = directory.appendingPathComponent(cachedName)
                        if (try? Data(contentsOf: destination)) != bytes { try bytes.write(to: destination, options: .atomic); result.changed = true }
                        attachments.append(MailAttachment(name: name, cachedName: cachedName, bytes: bytes.count, part: part.number))
                    }
                    var record = CachedMail(id: id, subject: parsed.subject, sender: parsed.sender, recipients: parsed.recipients,
                        date: parsed.date > 0 ? parsed.date : stat.mtime, messageID: parsed.messageID, accountID: box.accountID, account: box.account,
                        mailboxID: box.id, mailbox: box.name, originalPath: path, body: parsed.body,
                        attachments: attachments, missingAttachments: missing, bodyUnavailable: parsed.unavailable)
                    record.sourceVersion = version
                    let target = directory.appendingPathComponent(CachedMail.fileName)
                    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                    let data = try encoder.encode(record)
                    if (try? Data(contentsOf: target)) != data { try data.write(to: target, options: .atomic); result.changed = true }
                    let kept = Set(attachments.map(\.cachedName) + [CachedMail.fileName])
                    for entry in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) where !kept.contains(entry.lastPathComponent) {
                        try fm.removeItem(at: entry); result.changed = true
                    }
                    result.messages += 1; result.attachments += attachments.count; result.missing += missing
                } catch { result.problems.append("\(URL(fileURLWithPath: path).lastPathComponent)：\(error.localizedDescription)") }
            }
        }
        // Per-message read failures keep their previous cache. Never mistake incomplete enumeration for deletion.
        if complete {
            for directory in try fm.contentsOfDirectory(at: cache, includingPropertiesForKeys: [.isDirectoryKey])
                where directory.lastPathComponent.count == 64 && !seen.contains(directory.lastPathComponent) {
                try fm.removeItem(at: directory); result.changed = true
            }
        }
        return result
    }
}
