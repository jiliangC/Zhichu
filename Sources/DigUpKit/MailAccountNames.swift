import Foundation

/// Resolves Mail's storage UUIDs to the account descriptions used by Internet Accounts and Mail.
/// Only identifier/description columns are read; no account credentials, tokens, or server connections.
enum MailAccountNames {
    static func load(mailRoot: URL, accountIDs: Set<String>) -> [String: String] {
        guard !accountIDs.isEmpty else { return [:] }
        let library = mailRoot.deletingLastPathComponent()
        var names: [String: String] = [:]
        // Newer macOS uses Accounts4; older installations may still have Accounts3 alongside it.
        // An optional/unavailable name catalog must never make readable messages unavailable.
        for version in [4, 3] {
            let url = library.appendingPathComponent("Accounts/Accounts\(version).sqlite")
            guard let found = try? readDatabase(at: url, accountIDs: accountIDs) else { continue }
            names.merge(found) { first, _ in first }
        }
        return names
    }

    static func readDatabase(at url: URL, accountIDs: Set<String>) throws -> [String: String] {
        guard !accountIDs.isEmpty else { return [:] }
        let db = try Database(path: url.path, readOnly: true)
        var names: [String: String] = [:]
        // Deliberately do not SELECT * from this system database.
        let placeholders = Array(repeating: "?", count: accountIDs.count).joined(separator: ",")
        try db.query("SELECT ZIDENTIFIER, ZACCOUNTDESCRIPTION FROM ZACCOUNT WHERE lower(ZIDENTIFIER) IN (\(placeholders))",
                     accountIDs.map { .text($0.lowercased()) }) { row in
            guard let id = row.text(0), !id.isEmpty, let description = row.text(1) else { return }
            let name = description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            names[id.lowercased()] = name
        }
        return names
    }
}
