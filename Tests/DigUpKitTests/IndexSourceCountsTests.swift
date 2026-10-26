import Foundation
import Testing
@testable import DigUpKit

@Suite struct IndexSourceCountsTests {
    @Test func sourceOwnershipIncludesPendingAttachmentsFailuresAndLongFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SourceCounts-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try IndexStore(directory: dir)
        func add(_ path: String, kind: FileKind, state: String, info: [String: String] = [:]) throws {
            let id = try store.insert(Candidate(path: path, kind: kind, size: 1, mtime: 1, inode: 1, device: 1))
            if state != "pending" || !info.isEmpty { try store.finish(id, state: state, info: info) }
        }
        try add("/files/ready.txt", kind: .doc, state: "done")
        try add("/files/bad.pdf", kind: .pdf, state: "failed")
        try add("/files/later.txt", kind: .doc, state: "pending")
        try add("/cache/message.zhmail", kind: .mail, state: "done")
        try add("/cache/attachment.pdf", kind: .pdf, state: "pending", info: ["mail_id": "1"])
        try add("/cache/book.pdf", kind: .pdf, state: "partial", info: ["mail_id": "1"])
        try add("/cache/skip.png", kind: .image, state: "skipped", info: ["mail_id": "1"])
        // A cached attachment whose parent metadata is temporarily unreadable still belongs to mail.
        try add(dir.appendingPathComponent("MailSources/message/lost.pdf").path, kind: .pdf, state: "pending")
        let counts = try store.sourceCounts()
        #expect(counts[.folders]?.files == 3)
        #expect(counts[.folders]?.searchable == 1)
        #expect(counts[.folders]?.pending == 1)
        #expect(counts[.folders]?.failed == 1)
        #expect(counts[.mail]?.files == 5)
        #expect(counts[.mail]?.messages == 1 && counts[.mail]?.attachments == 4)
        #expect(counts[.mail]?.searchableMessages == 1 && counts[.mail]?.searchableAttachments == 1)
        #expect(counts[.mail]?.pending == 2 && counts[.mail]?.unfinished == 1 && counts[.mail]?.skipped == 1)
        store.scope = ["/files"]
        #expect(try store.sourceCounts()[.mail]?.files == 0)
        #expect(try store.sourceCounts()[.folders]?.files == 3)
    }
    @Test func incrementalEventsMatchPersistedStatesAndProtocolRoundTrip() {
        var counts = IndexSourceCounts()
        counts.include(kind: .mail, state: "pending", count: 3, source: .mail)
        counts.include(kind: .pdf, state: "pending", count: 1, source: .mail)
        counts.finishedPending(kind: .mail, state: "done", source: .mail)
        counts.finishedPending(kind: .mail, state: "failed", source: .mail)
        counts.finishedPending(kind: .pdf, state: "partial", source: .mail)
        #expect(counts.files == 4 && counts.pending == 1 && counts.processed == 3)
        #expect(counts.searchable == 2 && counts.failed == 1 && counts.unfinished == 1)
        #expect(counts.messages == 3 && counts.attachments == 1)
        #expect(counts.searchableMessages == 1 && counts.searchableAttachments == 1)
        #expect(counts.fraction == 0.75)
        #expect(IndexSourceCounts(fields: counts.fields) == counts)
    }
}
