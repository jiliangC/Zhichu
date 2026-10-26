import AppKit
import DigUpKit
import Observation

/// State the menubar, the panel and the windows share. Engine updates arrive on the main thread.
@Observable
final class AppModel {
    var status = EngineStatus()
    var settings: AppSettings
    var hotkey: KeyCombo?
    let download: ModelDownload
    var mail: MailController!
    /// A newer 知处 the daily check found ("0.6.1"), until you open it (`Updates`).
    var updateAvailable: String?

    init(settings: AppSettings, download: ModelDownload) {
        self.settings = settings
        self.download = download
    }

    var hasFolders: Bool { !settings.roots.isEmpty || settings.mail.enabled }
    /// Code search is on (there are code folders).
    var hasCode: Bool { !settings.codeRoots.isEmpty }

    /// One line for the menu and the windows: what the index is doing.
    var statusLine: String {
        let status = self.status
        guard hasFolders else { return "尚未选择文件夹" }
        if let reason = status.powerBlocker { return "索引更新已暂停 · \(reason)" }
        switch status.activity {
        case .starting: return "正在启动…"
        case .failed(let problem): return "⚠︎ \(problem)"
        case .syncing: return settings.mail.enabled ? "正在检查资料索引队列…" : "正在检查文件夹…"
        case .indexing(let done, let total):
            if let source = currentIndexSource, !status.sources.isEmpty { return sourceStatusLine(source) }
            let percent = total > 0 ? Int(Double(done) / Double(total) * 100) : 0
            return "正在建立资料索引 \(percent)% · \(done.formatted()) / \(total.formatted())"
        case .finishing(let done, let total, let files):
            if let source = currentIndexSource, !status.sources.isEmpty { return sourceStatusLine(source) }
            let percent = total > 0 ? Int(Double(done) / Double(total) * 100) : 0
            return "正在补齐 \(files.formatted()) 个长文件 · \(percent)%"
        case .idle:
            if let line = downloadLine { return line }
            if let code = status.code.indexing, code.total > 0 {
                let percent = Int(Double(code.done) / Double(code.total) * 100)
                return "代码索引 \(percent)% · \(code.done.formatted()) / \(code.total.formatted())"
            }
            if !status.sources.isEmpty {
                if let source = IndexSource.allCases.first(where: { counts(for: $0).pending > 0 || counts(for: $0).unfinished > 0 }) {
                    return sourceStatusLine(source)
                }
                return indexedSourcesLine + (status.paused ? " · 已暂停" : "")
            }
            let waiting = "\(status.pending.formatted()) 个文件等待索引"
            if status.pending > 0, status.paused { return "已暂停 · \(waiting)" }
            if let until = status.heldUntil, !status.paused {
                let when = "\(until.formatted(date: .omitted, time: .shortened)) 开始索引"
                return (status.pending > 0 ? waiting : "已索引 \(status.searchable.formatted()) 个文件") + " · " + when
            }
            if status.pending > 0, let reason = status.waitingFor { return "\(waiting) · \(reason)" }
            if status.pending > 0 { return waiting }
            if status.unfinished > 0 {
                let rest = "\(status.unfinished.formatted()) 个长文件待补齐"
                if status.paused { return "已暂停 · \(rest)" }
                if let reason = status.waitingFor { return "\(rest) · \(reason)" }
            }
            return "已索引 \(status.searchable.formatted()) 个文件" + (status.paused ? " · 已暂停" : "")
        }
    }

    /// While the model isn't there, how its download goes.
    private var downloadLine: String? {
        switch download.phase {
        case .ready: nil
        case .downloading: "正在下载模型 · \(Int(download.fraction * 100))%"
        case .verifying: "正在校验模型文件…"
        case .retrying: "模型下载正在等待网络"
        case .failed: "⚠︎ 模型下载已停止"
        case .needed: status.pending > 0 ? "尚未下载模型" : nil
        }
    }

    /// 0…1 for the menubar ring and progress bars: the model download, then an indexing pass or the rest of long files.
    var progress: Double? {
        if download.isActive { return download.fraction }
        if status.powerBlocker != nil { return nil }
        switch status.activity {
        case .indexing(let done, let total) where total > 0:
            if let source = currentIndexSource, !status.sources.isEmpty { return counts(for: source).fraction }
            return Double(done) / Double(total)
        case .finishing(let done, let total, _) where total > 0: return Double(done) / Double(total)
        case .idle:
            guard let code = status.code.indexing, code.total > 0 else { return nil }
            return Double(code.done) / Double(code.total)
        default: return nil
        }
    }

    /// One line about the code index, for Settings → Code: "812 code files indexed", "Indexing code 42%…".
    var codeStatusLine: String {
        let code = status.code
        guard hasCode else { return "代码搜索尚未开启" }
        if let reason = status.powerBlocker { return "代码索引更新已暂停 · \(reason)" }
        if !download.isReady { return "模型下载完成后开始读取代码" }
        if let indexing = code.indexing, indexing.total > 0 {
            let percent = Int(Double(indexing.done) / Double(indexing.total) * 100)
            return "代码索引 \(percent)% · \(indexing.done.formatted()) / \(indexing.total.formatted())"
        }
        let waiting = "\(code.pending.formatted()) 个代码文件等待索引"
        if code.pending > 0, status.paused { return "已暂停 · \(waiting)" }
        if code.pending > 0, let reason = status.waitingFor { return "\(waiting) · \(reason)" }
        if code.pending > 0, let until = status.heldUntil {
            return "\(waiting) · \(until.formatted(date: .omitted, time: .shortened)) 开始索引"
        }
        if code.pending > 0, status.pending > 0 { return waiting + " · 将在其他文件之后处理" }
        return "已索引 \(code.searchable.formatted()) 个代码文件" + (code.pending > 0 ? " · " + waiting : "")
    }

    /// A few words for the search bar while results may be incomplete: "Indexing 42%", "Downloading model · 42%".
    var activityBadge: String? {
        if status.powerBlocker != nil { return "等待接通电源" }
        if download.isActive { return "下载模型 · \(Int(download.fraction * 100))%" }
        if case .indexing(let done, let total) = status.activity, total > 0 {
            if let source = currentIndexSource, !status.sources.isEmpty {
                return (source == .mail ? "邮件索引 " : "文件夹索引 ") + "\(Int(counts(for: source).fraction * 100))%"
            }
            return "索引进度 \(Int(Double(done) / Double(total) * 100))%"
        }
        if status.paused, status.pending > 0 { return "索引已暂停" }
        return nil
    }

    /// Why meaning search can't run yet (words still match), or nil.
    var meaningUnavailable: String? {
        guard !download.isReady else { return nil }
        if download.isActive {
            return "模型下载完成前仅匹配关键词（\(Int(download.fraction * 100))%）"
        }
        return "模型尚未下载，目前仅匹配关键词"
    }

    /// Why results may be incomplete right now, or nil.
    var resultsCaveat: String? {
        if let meaningUnavailable { return meaningUnavailable }
        if case .indexing(let done, let total) = status.activity, total > 0 {
            return "仍在索引中（\(Int(Double(done) / Double(total) * 100))%），部分文件尚未加入"
        }
        if status.pending > 0 {
            return "还有 \(status.pending.formatted()) 项内容尚未索引"
        }
        return nil
    }
}
