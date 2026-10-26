import Foundation

/// Content ownership, independent of the attachment's physical type (PDF, document, image…).
public enum IndexSource: String, Sendable, CaseIterable { case folders, mail }

/// Persisted work states for one source. Completion includes explicit failures/skips, shown separately from searchable items.
public struct IndexSourceCounts: Sendable, Equatable {
    public var files = 0, searchable = 0, pending = 0, failed = 0, skipped = 0, unfinished = 0
    public var messages = 0, attachments = 0, searchableMessages = 0, searchableAttachments = 0
    public init() {}
    public var processed: Int { max(0, files - pending) }
    public var fraction: Double { files > 0 ? min(1, max(0, Double(processed) / Double(files))) : 0 }

    public mutating func include(kind: FileKind, state: String, count: Int, source: IndexSource) {
        files += count
        if source == .mail {
            if kind == .mail { messages += count } else { attachments += count }
        }
        addState(kind: kind, state: state, count: count, source: source)
    }

    /// A pending file is committed once by Indexer.run. No per-file GROUP BY over the whole library is needed.
    public mutating func finishedPending(kind: FileKind, state: String, source: IndexSource) {
        pending = max(0, pending - 1)
        addState(kind: kind, state: state, count: 1, source: source)
    }
    private mutating func addState(kind: FileKind, state: String, count: Int, source: IndexSource) {
        switch state {
        case "done", "partial":
            searchable += count
            if source == .mail {
                if kind == .mail { searchableMessages += count } else { searchableAttachments += count }
            }
            if state == "partial" { unfinished += count }
        case "pending": pending += count
        case "failed": failed += count
        default: skipped += count
        }
    }
    public var fields: [String: Int] {
        ["files": files, "searchable": searchable, "pending": pending, "failed": failed, "skipped": skipped,
         "unfinished": unfinished, "messages": messages, "attachments": attachments,
         "searchable_messages": searchableMessages, "searchable_attachments": searchableAttachments]
    }
    public init(fields: [String: Int]) {
        files = fields["files"] ?? 0; searchable = fields["searchable"] ?? 0; pending = fields["pending"] ?? 0
        failed = fields["failed"] ?? 0; skipped = fields["skipped"] ?? 0; unfinished = fields["unfinished"] ?? 0
        messages = fields["messages"] ?? 0; attachments = fields["attachments"] ?? 0
        searchableMessages = fields["searchable_messages"] ?? 0; searchableAttachments = fields["searchable_attachments"] ?? 0
    }
}
