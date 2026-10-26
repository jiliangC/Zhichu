import Foundation
import Testing
@testable import DigUpKit

@Suite struct MailAccountNamesTests {
    private func temporary() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MailNames-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func catalog(_ library: URL, version: Int = 4, rows: [(String, String)]) throws -> URL {
        let url = library.appendingPathComponent("Accounts/Accounts\(version).sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let db = try Database(path: url.path)
        try db.execute("CREATE TABLE ZACCOUNT (ZIDENTIFIER TEXT, ZACCOUNTDESCRIPTION TEXT)")
        for (id, name) in rows {
            try db.run("INSERT INTO ZACCOUNT VALUES (?, ?)", [.text(id), .text(name)])
        }
        try db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        return url
    }

    @Test func matchesExactAccountIDsAndPreservesMailboxSelection() throws {
        let library = try temporary(); defer { try? FileManager.default.removeItem(at: library) }
        let root = library.appendingPathComponent("Mail")
        for path in ["V10/70166269-QQ/Inbox.mbox/Messages", "V10/A4EBAC25-UNI/SendLater.mbox", "V10/Mailboxes/Outbox.mbox"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        let before = try AppleMailSource.discover(at: root)
        _ = try catalog(library, rows: [("70166269-qq", "QQ"), ("A4EBAC25-UNI", "st.gxu.edu.cn"), ("OTHER", "Unrelated private account")])
        let after = try AppleMailSource.discover(at: root)
        #expect(after.first { $0.accountID == "70166269-QQ" }?.account == "QQ")
        #expect(after.first { $0.accountID == "A4EBAC25-UNI" }?.account == "st.gxu.edu.cn")
        #expect(after.first { $0.accountID == "Mailboxes" }?.account == "我的 Mac")
        #expect(after.first { $0.accountID == "A4EBAC25-UNI" }?.name == "稍后发送")
        #expect(after.first { $0.accountID == "Mailboxes" }?.name == "发件箱")
        #expect(before.map(\.id) == after.map(\.id))
        #expect(Set(after.map(\.accountID)) == Set(before.map(\.accountID)))
    }

    @Test func optionalCatalogAndUserOverride() throws {
        let library = try temporary(); defer { try? FileManager.default.removeItem(at: library) }
        let root = library.appendingPathComponent("Mail")
        let message = root.appendingPathComponent("V10/UUID/Inbox.mbox/Messages/1.eml")
        try FileManager.default.createDirectory(at: message.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("Subject: hello\r\n\r\nbody".utf8).write(to: message)
        #expect(try AppleMailSource.discover(at: root).first?.account == "邮箱 UUID")
        #expect(!FileManager.default.fileExists(atPath: library.appendingPathComponent("Accounts/Accounts4.sqlite").path))
        _ = try catalog(library, version: 3, rows: [("UUID", "旧名称")])
        _ = try catalog(library, rows: [("UUID", "新名称")])
        #expect(try AppleMailSource.discover(at: root).first?.account == "新名称")
        var config = MailConfiguration(); config.enabled = true; config.accountNames = ["UUID": "自定义名称"]
        let result = try AppleMailSource.sync(at: root, to: library.appendingPathComponent("cache"), configuration: config)
        #expect(result.mailboxes.first?.account == "自定义名称")
        #expect(result.messages == 1)
    }

    @Test func catalogIsReadOnlyAndIgnoresUnrelatedAccounts() throws {
        let library = try temporary(); defer { try? FileManager.default.removeItem(at: library) }
        let url = try catalog(library, rows: [("UUID", "QQ"), ("OTHER", "Other account"), ("BLANK", "  ")])
        let data = try Data(contentsOf: url)
        #expect(try MailAccountNames.readDatabase(at: url, accountIDs: ["uuid", "blank"]) == ["uuid": "QQ"])
        let reader = try Database(path: url.path, readOnly: true)
        #expect(throws: Database.Failure.self) { try reader.execute("DELETE FROM ZACCOUNT") }
        #expect(try Data(contentsOf: url) == data)
        let absent = library.appendingPathComponent("absent.sqlite")
        #expect(throws: Database.Failure.self) { _ = try Database(path: absent.path, readOnly: true) }
        #expect(!FileManager.default.fileExists(atPath: absent.path))
    }

    @Test func cachedSourcesCanBeRestoredWithoutReadingMailOriginals() throws {
        let library = try temporary(); defer { try? FileManager.default.removeItem(at: library) }
        let store = try IndexStore(directory: library.appendingPathComponent("index"))
        // Deliberately no Mail root exists. Only previously indexed provenance may be used.
        func add(_ kind: String, _ name: String) throws {
            let info = "{\"mail_mailbox_id\":\"box\",\"mail_account_id\":\"account\",\"mail_account\":\"\(name)\",\"mail_mailbox\":\"收件箱\"}"
            try store.db.run("INSERT INTO files(path,kind,size,mtime,inode,device,state,info) VALUES (?,?,1,1,0,0,'done',?)",
                             [.text(UUID().uuidString), .text(kind), .text(info)])
        }
        try add("mail", "QQ"); try add("mail", "QQ renamed"); try add("pdf", "QQ")
        let boxes = try AppleMailSource.cachedMailboxes(indexFile: store.file)
        #expect(boxes.count == 1)
        #expect(boxes.first?.id == "box")
        #expect(boxes.first?.accountID == "account")
        #expect(boxes.first?.messagePaths.count == 2, "Do not count attachments as messages")
        #expect(boxes.first?.path == "")
        var count: Int64 = 0
        try store.db.query("SELECT count(*) FROM files") { count = $0.int(0) }
        #expect(count == 3)
    }
}
