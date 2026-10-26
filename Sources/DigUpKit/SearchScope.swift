import Foundation

/// A query's permitted library, optionally narrowed to one directory. This never changes the indexer's scope.
public struct SearchScope: Sendable {
    public let folders: [String]
    public let skipped: [String]
    public let excludedTypes: [String]
    public let within: String?
    public let mailAccount: String?
    public let mailboxes: [String]?
    public let mailCache: String?

    public init(folders: [String], skipped: [String] = [], excludedTypes: [String] = [], within: String? = nil, mailAccount: String? = nil, mailboxes: [String]? = nil, mailCache: String? = nil) {
        self.folders = folders
        self.skipped = skipped
        self.excludedTypes = excludedTypes
        self.within = within
        self.mailAccount = mailAccount
        self.mailboxes = mailboxes
        self.mailCache = mailCache
    }

    /// Bound path ranges use the existing path index; a slash boundary keeps Test and Test2 separate.
    /// A separately chosen directory inside a skipped directory remains searchable, as in FolderSelection.
    var predicate: (sql: String, values: [SQLValue]) {
        var values: [SQLValue] = []
        func under(_ folder: String) -> String {
            let ranges = IndexStore.pathRanges(under: folder)
            values += ranges.flatMap { [.text($0.from), .text($0.to)] }
            return "(" + ranges.map { _ in "(path >= ? AND path < ?)" }.joined(separator: " OR ") + ")"
        }
        let choices = folders.map { root in
            var parts = [under(root)]
            for skip in skipped where FolderSelection.isInside(skip, root) {
                parts.append("NOT " + under(skip))
            }
            return "(" + parts.joined(separator: " AND ") + ")"
        }
        var clauses = [choices.isEmpty ? "0" : "(" + choices.joined(separator: " OR ") + ")"]
        if let within { clauses.append(under(within)) }
        if let mailAccount {
            clauses.append("json_extract(info, '$.mail_account_id') = ?")
            values.append(.text(mailAccount))
        }
        if let mailCache, let mailboxes {
            let outside = "NOT " + under(mailCache)
            let allowed = mailboxes.isEmpty ? "0" : "json_extract(info, '$.mail_mailbox_id') IN (" + mailboxes.map { _ in "?" }.joined(separator: ",") + ")"
            clauses.append("(" + outside + " OR (" + allowed + "))")
            values += mailboxes.map(SQLValue.text)
        }
        if let mailboxes {
            let allowed = mailboxes.isEmpty ? "0" : "json_extract(info, '$.mail_mailbox_id') IN (" + mailboxes.map { _ in "?" }.joined(separator: ",") + ")"
            clauses.append("(json_extract(info, '$.mail_id') IS NULL OR (" + allowed + "))")
            values += mailboxes.map(SQLValue.text)
        }
        for type in excludedTypes {
            let suffix = "." + type.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            clauses.append("substr(lower(path), -?) != ?")
            values += [.int(Int64(suffix.count)), .text(suffix)]
        }
        return (clauses.joined(separator: " AND "), values)
    }
}
