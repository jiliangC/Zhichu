import Foundation
import Testing
@testable import DigUpKit

@Suite struct MailSourceTests {
    private var fixture: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Mail/Mail") }
    private func temporary() throws -> URL {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MailTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    private func read(_ number: String) throws -> AppleMailSource.Parsed {
        let url = fixture.appendingPathComponent("V10/demo-account/Inbox.mbox/Messages/\(number).emlx")
        return try AppleMailSource.parse(Data(contentsOf: url), emlx: true)
    }
    @Test func chineseMIMEAndEMLXBoundaries() throws {
        let utf = try read("1001")
        #expect(utf.subject == "第四季度采购报价确认")
        #expect(utf.sender.contains("王静"))
        #expect(utf.body.contains("报价已确认"))
        #expect(!utf.body.contains("元数据不应混入正文"))
        #expect(try read("1002").body.contains("项目验收"))
        #expect(try read("1003").body.contains("採購"))
        let html = try read("1004")
        #expect(html.body.contains("设备发货"))
        #expect(!html.body.contains("NEVER_INDEX_SCRIPT"))
        #expect(!html.body.contains("example.invalid/pixel"))
        let alternate = try read("1005").body
        #expect(alternate.components(separatedBy: "采购预算已确认").count == 2, "Decoded: \(alternate)")
        #expect(throws: (any Error).self) { try AppleMailSource.parse(Data("999999\nshort".utf8), emlx: true) }
    }
    @Test func optInAndAttachmentOwnership() throws {
        let temp = try temporary(); defer { try? FileManager.default.removeItem(at: temp) }
        var config = MailConfiguration()
        let cache = temp.appendingPathComponent("cache")
        #expect(try AppleMailSource.sync(at: fixture, to: cache, configuration: config).messages == 0)
        #expect(!FileManager.default.fileExists(atPath: cache.path))
        config.enabled = true
        let result = try AppleMailSource.sync(at: fixture, to: cache, configuration: config)
        #expect(result.messages == 7)
        #expect(result.changed)
        #expect(!((try AppleMailSource.sync(at: fixture, to: cache, configuration: config)).changed))
        #expect(result.attachments == 2)
        #expect(result.problems.isEmpty)
        let records = try FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil).map { try CachedMail.read($0.appendingPathComponent(CachedMail.fileName)) }
        #expect(records.count == 7)
        #expect(records.filter { !$0.attachments.isEmpty }.count == 2)
        for record in records where !record.attachments.isEmpty {
            let attachment = record.attachments[0]
            #expect(attachment.name == "报价单.pdf")
            let url = cache.appendingPathComponent(record.id).appendingPathComponent(attachment.cachedName)
            #expect(record.info(for: url)["mail_attachment"] == "报价单.pdf")
            #expect(CachedMail.context(for: url)?.subject == record.subject)
        }
        config.attachmentMode = "none"
        #expect(try AppleMailSource.sync(at: fixture, to: cache, configuration: config).attachments == 0)
        #expect(try FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil).allSatisfy {
            (try? FileManager.default.contentsOfDirectory(atPath: $0.path).count) == 1
        })
        config.mailboxIDs = []
        #expect(try AppleMailSource.sync(at: fixture, to: cache, configuration: config).messages == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: cache.path).isEmpty)
    }
    @Test func failedOrCancelledScanNeverPrunesPreviousCache() throws {
        let temp = try temporary(); defer { try? FileManager.default.removeItem(at: temp) }
        var config = MailConfiguration(); config.enabled = true
        let cache = temp.appendingPathComponent("cache")
        _ = try AppleMailSource.sync(at: fixture, to: cache, configuration: config)
        #expect(throws: CancellationError.self) {
            try AppleMailSource.sync(at: fixture, to: cache, configuration: config, shouldStop: { true })
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: cache.path).count == 7)
        #expect(throws: (any Error).self) {
            try AppleMailSource.sync(at: temp.appendingPathComponent("absent"), to: cache, configuration: config)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: cache.path).count == 7)
    }
    @Test func productionIndexerKeepsMailProvenanceAndAttachmentPage() throws {
        let temp = try temporary(); defer { try? FileManager.default.removeItem(at: temp) }
        var config = MailConfiguration(); config.enabled = true
        let cache = temp.appendingPathComponent("cache")
        _ = try AppleMailSource.sync(at: fixture, to: cache, configuration: config)
        let store = try IndexStore(directory: temp.appendingPathComponent("index"))
        var options = IndexOptions(); options.minPageText = 20
        let indexer = try Indexer(store: store, options: options, makeEmbedder: { FakeEmbedder() })
        #expect(try indexer.sync([cache]).added == 9)
        let states = try indexer.run()
        #expect(states["failed"] == nil)
        let searcher = try Searcher(store: store, loadVectors: false)
        let body = try searcher.search("项目验收", queryVector: nil, kinds: [.mail])
        #expect(body.first?.kind == .mail)
        #expect(body.first?.info["mail_subject"] == "设备验收安排")
        let hits = try searcher.search("含税报价", queryVector: nil, kinds: [.mail])
        #expect(hits.count == 2)
        #expect(hits.allSatisfy { $0.loc == 3 && $0.kind == .pdf && $0.info["mail_attachment"] == "报价单.pdf" })
        #expect(try searcher.search("含税报价", queryVector: nil, kinds: [.pdf]).isEmpty)
        let scope = SearchScope(folders: [cache.path], mailAccount: "other", mailboxes: nil)
        #expect(try searcher.search("含税报价", queryVector: nil, scope: scope).isEmpty)
        let empty = SearchScope(folders: [cache.path], mailboxes: [])
        #expect(try searcher.search("含税报价", queryVector: nil, scope: empty).isEmpty)
        let id = try #require(body.first?.info["mail_mailbox_id"])
        let allowed = SearchScope(folders: [cache.path], mailboxes: [id])
        #expect(try searcher.search("项目验收", queryVector: nil, scope: allowed).count == 1)
        #expect(try indexer.sync([cache]).changed == 0)
    }
    @Test func oneMailUsesOneResultBeforeFinalLimit() throws {
        let temp = try temporary(); defer { try? FileManager.default.removeItem(at: temp) }
        let store = try IndexStore(directory: temp)
        for (index, mail) in ["A", "A", "A", "B"].enumerated() {
            let file = try store.insert(Candidate(path: "/cache/\(index).txt", kind: .mail, size: 1, mtime: 1, inode: UInt64(index), device: 1))
            try store.addSegment(file: file, kind: .chunk, modality: .text, text: "报价资料", vector: nil)
            try store.finish(file, state: "done", info: ["mail_id": mail])
        }
        let hits = try Searcher(store: store, loadVectors: false).search("报价资料", queryVector: nil, kinds: [.mail], limit: 2)
        #expect(hits.count == 2)
        #expect(Set(hits.compactMap { $0.info["mail_id"] }) == ["A", "B"])
    }
    @Test func eightBitAndBinaryMultipartPreserveOriginalBytes() throws {
        let binary = Data([0, 255, 233, 13, 10, 128, 45, 45, 0])
        var raw = Data("Subject: Binary test\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary=bound\r\n\r\n--bound\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: 8bit\r\n\r\n中文正文\r\n--bound\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=test.bin\r\nContent-Transfer-Encoding: binary\r\n\r\n".utf8)
        raw += binary; raw += Data("\r\n--bound--\r\n".utf8)
        let parsed = try AppleMailSource.parse(raw, emlx: false)
        #expect(parsed.body.contains("中文正文"))
        #expect(parsed.parts.first?.data == binary)
        var body = "Content-Type: text/plain\r\n\r\nhello"
        for i in 0..<40 { body = "Content-Type: multipart/mixed; boundary=b\(i)\r\n\r\n--b\(i)\r\n" + body + "\r\n--b\(i)--\r\n" }
        #expect(throws: (any Error).self) { try AppleMailSource.parse(Data(body.utf8), emlx: false) }
    }
    @Test func removingMailSourceHidesCachedRowsEvenInsideAHomeFolderScope() throws {
        let temp = try temporary(); defer { try? FileManager.default.removeItem(at: temp) }
        let store = try IndexStore(directory: temp)
        let file = try store.insert(Candidate(path: "/home/user/index.noindex/MailSources/message.zhmail", kind: .mail, size: 1, mtime: 1, inode: 1, device: 1))
        try store.addSegment(file: file, kind: .chunk, modality: .text, text: "报价资料", vector: nil)
        let scope = SearchScope(folders: ["/home/user"], mailboxes: [], mailCache: "/home/user/index.noindex/MailSources")
        #expect(try Searcher(store: store, loadVectors: false).search("报价资料", queryVector: nil, scope: scope).isEmpty)
    }

}
