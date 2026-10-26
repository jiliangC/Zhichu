import Foundation
import Testing
@testable import DigUpKit
@testable import ZhichuApp

@Suite @MainActor struct SourceProgressTests {
    func model() -> AppModel {
        var settings = AppSettings.load()
        settings.roots = [URL(fileURLWithPath: "/Test")]
        settings.mail.enabled = true
        return AppModel(settings: settings, download: ModelDownload(folder: URL(fileURLWithPath: "/nonexistent-test-models")))
    }
    @Test func mailWorkDoesNotChangeFolderCountsOrFolderCompletion() {
        let model = model()
        var files = IndexSourceCounts(), mail = IndexSourceCounts()
        files.include(kind: .doc, state: "done", count: 165, source: .folders)
        mail.include(kind: .mail, state: "done", count: 100, source: .mail)
        mail.include(kind: .mail, state: "pending", count: 2600, source: .mail)
        mail.include(kind: .pdf, state: "pending", count: 200, source: .mail)
        model.status.sources = [.folders: files, .mail: mail]
        model.status.activity = .indexing(done: 100, total: 2900)
        model.status.activeSource = .mail
        #expect(model.sourceStatusLine(.folders) == "文件夹索引处理完成")
        #expect(model.sourceDetail(.folders) == "共 165 个文件 · 165 项内容可搜索")
        #expect(model.statusLine == "正在建立邮件索引 3% · 100 / 2,900")
        #expect(model.sourceDetail(.mail).contains("2,700 封邮件、200 个附件"))
        #expect(model.progress == mail.fraction)
        model.status.paused = true
        #expect(model.sourceStatusLine(.mail) == "邮件索引已暂停")
        #expect(model.sourceStatusLine(.folders) == "文件夹索引处理完成")
        model.status.activity = .failed("索引任务异常退出")
        #expect(model.sourceStatusLine(.mail).hasPrefix("邮件索引已停止"))
        #expect(model.sourceStatusLine(.folders) == "文件夹索引处理完成")
    }
    @Test func interleavedSourcesAndCompletionKeepTheirOwnTotals() {
        let model = model()
        var files = IndexSourceCounts(), mail = IndexSourceCounts()
        files.include(kind: .doc, state: "pending", count: 10, source: .folders)
        mail.include(kind: .mail, state: "done", count: 2, source: .mail)
        mail.include(kind: .pdf, state: "done", count: 1, source: .mail)
        model.status.sources = [.folders: files, .mail: mail]
        model.status.activity = .indexing(done: 1, total: 10)
        model.status.activeSource = .folders
        #expect(model.statusLine.hasPrefix("正在建立文件夹索引"))
        #expect(model.sourceStatusLine(.mail) == "邮件索引处理完成")
        #expect(model.indexedSourcesLine == "已索引 0 个文件 · 2 封邮件 · 1 个附件")
        files.finishedPending(kind: .doc, state: "failed", source: .folders)
        model.status.sources[.folders] = files
        #expect(model.sourceDetail(.folders).contains("1 项读取失败"))
        model.settings.mail.enabled = false
        #expect(model.counts(for: .mail).files == 0)
        #expect(!model.indexedSourcesLine.contains("邮件"))
    }
}
