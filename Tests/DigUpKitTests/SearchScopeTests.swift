import Foundation
import Testing
@testable import DigUpKit

@Suite struct SearchScopeTests {
    private func index() throws -> (URL, IndexStore) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SearchScope-\(UUID())")
        return (dir, try IndexStore(directory: dir))
    }

    @discardableResult private func add(_ path: String, to store: IndexStore, text: String = "季度合同明细",
                                        kind: FileKind = .doc, vector: [Float]? = nil) throws -> Int64 {
        let file = try store.insert(Candidate(path: path, kind: kind, size: 1, mtime: 1, inode: 1, device: 1))
        try store.addSegment(file: file, kind: .chunk, modality: .text, loc: 2, text: text, vector: vector)
        return file
    }

    @Test func scopeIncludesDescendantsButNotSimilarlyNamedSiblings() throws {
        let (dir, store) = try index()
        defer { try? FileManager.default.removeItem(at: dir) }
        for path in ["/资料/Test/合同.txt", "/资料/Test/项目/合同.txt", "/资料/Test2/合同.txt", "/下载/合同.txt"] {
            try add(path, to: store)
        }
        let search = try Searcher(store: store, loadVectors: false)
        let scope = SearchScope(folders: ["/资料/Test", "/资料/Test2", "/下载"], within: "/资料/Test")
        let hits = try search.search("季度合同", queryVector: nil, scope: scope)
        #expect(Set(hits.map(\.path)) == ["/资料/Test/合同.txt", "/资料/Test/项目/合同.txt"])
        #expect(hits.allSatisfy { $0.loc == 2 })
        #expect(try search.search("季度合同", queryVector: nil).count == 4)
        #expect(try search.search("季度合同", queryVector: nil, scope: SearchScope(folders: [])).isEmpty)
        #expect(try search.search("季度合同", queryVector: nil,
                                  scope: SearchScope(folders: ["/资料/Test"], within: "/未授权")).isEmpty)
    }

    @Test func scopesRespectSkipsReincludedRootsAndExcludedTypes() throws {
        let (dir, store) = try index()
        defer { try? FileManager.default.removeItem(at: dir) }
        let paths = ["/资料/合同.txt", "/资料/排除/合同.txt", "/资料/排除/保留/合同.txt", "/资料/合同.PDF"]
        for path in paths { try add(path, to: store) }
        let scope = SearchScope(folders: ["/资料", "/资料/排除/保留"], skipped: ["/资料/排除"],
                                excludedTypes: ["pdf"], within: "/资料")
        let search = try Searcher(store: store, loadVectors: false)
        #expect(Set(try search.search("季度合同", queryVector: nil, scope: scope).map(\.path)) == [paths[0], paths[2]])
    }

    @Test func directoryFilterRunsBeforeFTSAndExactNameCandidateLimits() throws {
        let (dir, store) = try index()
        defer { try? FileManager.default.removeItem(at: dir) }
        try store.db.transaction {
            for i in 0..<1100 { try add("/外部/\(i)/租房合同.txt", to: store, text: "quarterly agreement 合同明细") }
            try add("/目标/租房合同.txt", to: store, text: "quarterly agreement 合同明细")
        }
        let search = try Searcher(store: store, loadVectors: false)
        let scope = SearchScope(folders: ["/外部", "/目标"], within: "/目标")
        for query in ["quarterly", "合同明细", "租房合同.txt", "zufanghetong", "zfht"] {
            let hits = try search.search(query, queryVector: nil, limit: 1, scope: scope)
            #expect(hits.map(\.path) == ["/目标/租房合同.txt"], "Scoped lookup failed: \(query)")
        }
    }

    @Test func semanticCandidatesAreScopedBeforeFinalLimitAndKeepLocation() throws {
        let (dir, store) = try index()
        defer { try? FileManager.default.removeItem(at: dir) }
        var vector = [Float](repeating: 0, count: Vectors.dimension)
        vector[0] = 1
        for i in 0..<50 { try add("/外部/\(i).txt", to: store, text: "other", vector: vector) }
        try add("/目标/页面.txt", to: store, text: "other", vector: vector)
        let search = try Searcher(store: store)
        let hits = try search.search("a completely different description", queryVector: vector, limit: 1, zGate: -100,
                                     scope: SearchScope(folders: ["/外部", "/目标"], within: "/目标"))
        #expect(hits.map(\.path) == ["/目标/页面.txt"])
        #expect(hits.first?.loc == 2)
    }

    @Test func prefixFallbackAndTypeFiltersUseTheSelectedDirectory() throws {
        let (dir, store) = try index()
        defer { try? FileManager.default.removeItem(at: dir) }
        try add("/外部/a.txt", to: store, text: "grok")
        try add("/目标/a.txt", to: store, text: "grokipedia")
        try add("/目标/b.pdf", to: store, text: "grokipedia", kind: .pdf)
        let search = try Searcher(store: store, loadVectors: false)
        let scope = SearchScope(folders: ["/外部", "/目标"], within: "/目标")
        let hits = try search.search("grok", queryVector: nil, kinds: [.pdf], scope: scope)
        #expect(hits.map(\.path) == ["/目标/b.pdf"])
        #expect(try search.search("grok", queryVector: nil, kinds: [], scope: scope).isEmpty)
    }

    @Test func boundPathsHandleQuotesAndSQLWildcardsLiterally() throws {
        let (dir, store) = try index()
        defer { try? FileManager.default.removeItem(at: dir) }
        for path in ["/资料/50%_O'Reilly/合同.txt", "/资料/50abOReilly/合同.txt"] { try add(path, to: store) }
        let hits = try Searcher(store: store, loadVectors: false).search("季度合同", queryVector: nil,
            scope: SearchScope(folders: ["/资料"], within: "/资料/50%_O'Reilly"))
        #expect(hits.map(\.path) == ["/资料/50%_O'Reilly/合同.txt"])
    }
}
