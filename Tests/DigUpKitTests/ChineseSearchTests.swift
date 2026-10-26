import Foundation
import Testing
@testable import DigUpKit

@Suite struct ChineseSearchTests {
    private func temporaryIndex() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ZhichuTests-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func continuousChineseIsProseAndHighlightable() {
        #expect(SearchText.hasProse("承租人可以在本公寓内饲养宠物但应当保持环境卫生。"))
        #expect(!SearchText.hasProse("合同编号"))
        #expect(!SearchText.hasProse("12345678901234567890"))
        let text = "承租人可饲养宠物，但需要登记。"
        #expect(SearchText.matches(of: "宠物", in: text).map { String(text[$0]) } == ["宠物"])
        #expect(SearchText.snippet(text, terms: ["宠物"])?.contains("«宠物»") == true)
        let longText = String(repeating: "资料", count: 1000) + "宠物" + String(repeating: "条款", count: 1000)
        #expect((SearchText.snippet(longText, terms: ["宠物"])?.count ?? 0) < 160)
        #expect(Landmark.find(page: 2, texts: ["第一条租金说明", text], words: ["宠物"]) == "宠物")
    }

    @Test func keywordsFindChineseInsideSentencesAndFileNames() throws {
        let folder = try temporaryIndex()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try IndexStore(directory: folder)
        let pet = try store.insert(Candidate(path: "/资料/公寓租赁.pdf", kind: .pdf, size: 1, mtime: 1, inode: 1, device: 1))
        try store.addSegment(file: pet, kind: .page, modality: .text, loc: 2,
                             text: "第六条：承租人可在公寓内饲养宠物。合同编号 AB-2026。")
        let wrong = try store.insert(Candidate(path: "/资料/采购记录.txt", kind: .doc, size: 1, mtime: 1, inode: 2, device: 1))
        try store.addSegment(file: wrong, kind: .chunk, modality: .text, text: "宠爱家人，物品需妥善保管。")
        let searcher = try Searcher(store: store, loadVectors: false)
        let hits = try searcher.search("宠物", queryVector: nil)
        #expect(hits.map(\.path) == ["/资料/公寓租赁.pdf"])
        #expect(hits.first?.excerpt?.contains("«宠物»") == true)
        #expect(try searcher.search("公寓", queryVector: nil).first?.path == "/资料/公寓租赁.pdf")
        #expect(try searcher.search("AB-2026", queryVector: nil).first?.path == "/资料/公寓租赁.pdf")
        #expect(Searcher.kindHints("海边的小狗视频").contains(.video))
    }

    @Test func schemaFiveRetokenizesWithoutDroppingVectors() throws {
        let folder = try temporaryIndex()
        defer { try? FileManager.default.removeItem(at: folder) }
        do {
            let store = try IndexStore(directory: folder)
            let id = try store.insert(Candidate(path: "/合同.txt", kind: .doc, size: 1, mtime: 1, inode: 1, device: 1))
            try store.addSegment(file: id, kind: .chunk, modality: .text, text: "承租人可以饲养宠物", vector: Array(repeating: 0, count: 768))
            // Simulate an upstream v5 row, which kept continuous Chinese as a single FTS token.
            try store.db.execute("UPDATE fts SET body = '承租人可以饲养宠物', original = NULL WHERE name = ''; PRAGMA user_version = 5;")
        }
        let store = try IndexStore(directory: folder)
        let searcher = try Searcher(store: store, loadVectors: false)
        #expect(try searcher.search("宠物", queryVector: nil).first?.path == "/合同.txt")
        var vectors: Int64 = 0
        try store.db.query("SELECT count(*) FROM segments WHERE vec IS NOT NULL") { vectors = $0.int(0) }
        #expect(vectors == 1)
    }

    @Test func pinyinFindsFileNamesWithoutPollutingDocumentBodies() throws {
        let folder = try temporaryIndex()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try IndexStore(directory: folder)
        let id = try store.insert(Candidate(path: "/资料/租房合同.pdf", kind: .pdf, size: 1, mtime: 1, inode: 1, device: 1))
        try store.addSegment(file: id, kind: .page, modality: .text, text: "小狗可以入住这间公寓。")
        let searcher = try Searcher(store: store, loadVectors: false)
        #expect(try searcher.search("zufanghetong", queryVector: nil).first?.path == "/资料/租房合同.pdf")
        #expect(try searcher.search("zfht", queryVector: nil).first?.path == "/资料/租房合同.pdf")
        #expect(try searcher.search("xiaogou", queryVector: nil).isEmpty)
    }

    @Test func chineseScreenshotNamesUseOCR() {
        for path in ["/资料/截屏2026-10-24.png", "/资料/付款失败截图.png", "/截图/20261024.png", "/资料/微信截图_1024.png"] {
            #expect(Rules.isScreenshot(URL(fileURLWithPath: path)))
        }
        #expect(!Rules.isScreenshot(URL(fileURLWithPath: "/照片/海边的小狗.png")))
    }

    @Test func chineseQuestionWordsDoNotHideExactContent() throws {
        let folder = try temporaryIndex()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try IndexStore(directory: folder)
        let id = try store.insert(Candidate(path: "/财务预算.md", kind: .doc, size: 1, mtime: 1, inode: 1, device: 1))
        try store.addSegment(file: id, kind: .chunk, modality: .text, text: "所有报销必须附上发票，月底由财务统一核对。")
        let searcher = try Searcher(store: store, loadVectors: false)
        #expect(try searcher.search("月底需要什么报销材料", queryVector: nil).first?.path == "/财务预算.md")
    }
    @Test func exactFilenameLookupBeatsUnrelatedMediaButKeepsMeaningSearch() throws {
        let folder = try temporaryIndex()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try IndexStore(directory: folder)
        let name = try store.insert(Candidate(path: "/资料/晚餐准备.txt", kind: .doc, size: 1, mtime: 1, inode: 1, device: 1))
        try store.addSegment(file: name, kind: .chunk, modality: .text, text: "番茄炖牛肉，米饭和蔬菜沙拉。")
        var query = [Float](repeating: 0, count: 768)
        query[0] = 1
        for index in 0..<3 {
            let media = try store.insert(Candidate(path: "/资料/CLIP_\(index).mp4", kind: .video, size: 1, mtime: 1, inode: UInt64(index + 2), device: 1))
            try store.addSegment(file: media, kind: .frame, modality: .image, loc: 1, vector: query)
        }
        let searcher = try Searcher(store: store)
        for key in ["晚餐准备", "晚餐准备.txt", "wancanzhunbei", "wczb"] {
            let hits = try searcher.search(key, queryVector: query, zGate: -100)
            #expect(hits.map(\.path) == ["/资料/晚餐准备.txt"])
            #expect(hits.first?.segment == .name)
        }
        #expect(try searcher.search("海边活动", queryVector: query, zGate: -100).contains { $0.kind == .video })
        #expect(try searcher.search("wczb", queryVector: query, kinds: [.video], zGate: -100).allSatisfy { $0.kind == .video })
    }

    @Test func commonPolyphonicWordsAndLegacyAliasesRemainSearchable() throws {
        let folder = try temporaryIndex()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try IndexStore(directory: folder)
        for (offset, name) in ["上海地铁出行", "重庆音乐银行"].enumerated() {
            try store.insert(Candidate(path: "/资料/\(name).txt", kind: .doc, size: 1, mtime: 1, inode: UInt64(offset + 1), device: 1))
        }
        let searcher = try Searcher(store: store, loadVectors: false)
        for key in ["shanghaiditiechuxing", "shanghaidetiechuxing", "shdtcx", "shang hai di tie chu xing"] {
            #expect(try searcher.search(key, queryVector: nil).first?.path == "/资料/上海地铁出行.txt")
        }
        #expect(try searcher.search("chongqingyinyueyinhang", queryVector: nil).first?.path == "/资料/重庆音乐银行.txt")
    }

    @Test func simplifiedAndTraditionalKeywordsPreserveOriginalExcerpts() throws {
        let folder = try temporaryIndex()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try IndexStore(directory: folder)
        let id = try store.insert(Candidate(path: "/資料/財務備忘.txt", kind: .doc, size: 1, mtime: 1, inode: 1, device: 1))
        try store.addSegment(file: id, kind: .chunk, modality: .text, text: "請檢查預算報表，並儘快確認項目費用。")
        let id2 = try store.insert(Candidate(path: "/资料/旅游说明.txt", kind: .doc, size: 1, mtime: 1, inode: 2, device: 1))
        try store.addSegment(file: id2, kind: .chunk, modality: .text, text: "请携带护照和行李，提前办理登机手续。")
        let searcher = try Searcher(store: store, loadVectors: false)
        #expect(try searcher.search("预算报表", queryVector: nil).first?.path == "/資料/財務備忘.txt")
        #expect(try searcher.search("预算报表", queryVector: nil).first?.excerpt?.contains("預算") == true)
        #expect(try searcher.search("護照", queryVector: nil).first?.path == "/资料/旅游说明.txt")
        let original = "請檢查預算報表。"
        #expect(SearchText.matches(of: "预算", in: original).map { String(original[$0]) } == ["預算"])
    }

    @Test func schemaSixRebuildsFilenameAliasesAndTraditionalTextWithoutReembedding() throws {
        let folder = try temporaryIndex()
        defer { try? FileManager.default.removeItem(at: folder) }
        do {
            let store = try IndexStore(directory: folder)
            let id = try store.insert(Candidate(path: "/資料/上海地铁出行.txt", kind: .doc, size: 1, mtime: 1, inode: 1, device: 1))
            try store.addSegment(file: id, kind: .chunk, modality: .text, text: "請確認預算報表", vector: Array(repeating: 0.25, count: 768))
            try store.db.execute("UPDATE fts SET name = '上海地铁出行 shanghaidetiechuxing shdtcx' WHERE name != ''; UPDATE fts SET body = '請 確 認 預 算 報 表', original = '請確認預算報表' WHERE name = ''; PRAGMA user_version = 6;")
        }
        let store = try IndexStore(directory: folder)
        let searcher = try Searcher(store: store, loadVectors: false)
        #expect(try searcher.search("shanghaiditiechuxing", queryVector: nil).first?.path == "/資料/上海地铁出行.txt")
        #expect(try searcher.search("预算报表", queryVector: nil).first?.path == "/資料/上海地铁出行.txt")
        var vectorCount: Int64 = 0
        try store.db.query("SELECT count(*) FROM segments WHERE vec IS NOT NULL") { vectorCount = $0.int(0) }
        #expect(vectorCount == 1)
    }

    @Test func literalChinesePassageBeatsMediaOutlierAndPointsAtTheMatchingChunk() throws {
        let folder = try temporaryIndex()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try IndexStore(directory: folder)
        let note = try store.insert(Candidate(path: "/资料/工作备忘.txt", kind: .doc, size: 1, mtime: 1, inode: 1, device: 1))
        try store.addSegment(file: note, kind: .chunk, modality: .text, loc: 1, text: "前面是其他无关的说明。")
        try store.addSegment(file: note, kind: .chunk, modality: .text, loc: 2, text: "請攜帶預算報表和掃描收據。")
        var query = [Float](repeating: 0, count: 768); query[0] = 1
        let media = try store.insert(Candidate(path: "/资料/演示.mp4", kind: .video, size: 1, mtime: 1, inode: 2, device: 1))
        try store.addSegment(file: media, kind: .frame, modality: .image, loc: 3, vector: query)
        let searcher = try Searcher(store: store)
        let hits = try searcher.search("预算报表", queryVector: query, zGate: -100)
        #expect(hits.first?.path == "/资料/工作备忘.txt")
        #expect(hits.first?.loc == 2)
        #expect(hits.first?.excerpt?.contains("«預算報表»") == true)
        #expect(hits.contains { $0.path == "/资料/演示.mp4" })
    }

}
