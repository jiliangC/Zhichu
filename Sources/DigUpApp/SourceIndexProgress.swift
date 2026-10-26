import DigUpKit
import SwiftUI

extension AppModel {
    func counts(for source: IndexSource) -> IndexSourceCounts {
        if source == .mail, !settings.mail.enabled { return .init() }
        return status.sources[source] ?? .init()
    }
    var currentIndexSource: IndexSource? {
        if let source = status.activeSource { return source }
        let pending = IndexSource.allCases.filter { counts(for: $0).pending > 0 }
        return pending.count == 1 ? pending.first : nil
    }
    func sourceStatusLine(_ source: IndexSource) -> String {
        let title = source == .mail ? "邮件" : "文件夹"
        let counts = counts(for: source)
        if let reason = status.powerBlocker { return "\(title)索引更新已暂停 · \(reason)" }
        if source == .mail, counts.files == 0, mail?.syncing == true { return "正在读取邮件，准备索引…" }
        if source == .mail, let mail, !mail.isAvailable, !mail.syncing { return "邮件来源暂不可用" }
        if counts.pending > 0 || counts.unfinished > 0, case .failed(let reason) = status.activity { return "\(title)索引已停止 · \(reason)" }
        if counts.pending > 0 {
            if status.paused { return "\(title)索引已暂停" }
            if status.waitingForModel || download.isActive { return "\(title)索引等待模型就绪" }
            if let until = status.heldUntil { return "\(title)索引将于 \(until.formatted(date: .omitted, time: .shortened)) 开始" }
            if currentIndexSource == source, case .indexing = status.activity {
                return "正在建立\(title)索引 \(Int(counts.fraction * 100))% · \(counts.processed.formatted()) / \(counts.files.formatted())"
            }
            if let reason = status.waitingFor { return "\(title)索引等待中 · \(reason)" }
            return "\(title)索引等待中 · \(counts.pending.formatted()) 项待处理"
        }
        if counts.unfinished > 0 {
            if status.paused { return "\(title)索引补齐已暂停" }
            if currentIndexSource == source, case .finishing = status.activity { return "正在补齐\(title)的长内容" }
            return "\(title)有 \(counts.unfinished.formatted()) 项长内容待补齐"
        }
        if counts.files == 0 { return source == .mail ? "尚无需要建立索引的邮件" : "尚无需要建立索引的文件" }
        return "\(title)索引处理完成"
    }
    func sourceDetail(_ source: IndexSource) -> String {
        let counts = counts(for: source)
        var text = source == .mail ? "共 \(counts.messages.formatted()) 封邮件、\(counts.attachments.formatted()) 个附件"
            : "共 \(counts.files.formatted()) 个文件"
        text += " · \(counts.searchable.formatted()) 项内容可搜索"
        if counts.pending > 0 { text += " · \(counts.pending.formatted()) 项待处理" }
        if counts.unfinished > 0 { text += " · \(counts.unfinished.formatted()) 项长内容待补齐" }
        if counts.failed > 0 { text += " · \(counts.failed.formatted()) 项读取失败" }
        if counts.skipped > 0 { text += " · \(counts.skipped.formatted()) 项已跳过" }
        return text
    }
    var indexedSourcesLine: String {
        let files = counts(for: .folders), mail = counts(for: .mail)
        var parts = [String]()
        if !settings.roots.isEmpty { parts.append("\(files.searchable.formatted()) 个文件") }
        if settings.mail.enabled {
            parts.append("\(mail.searchableMessages.formatted()) 封邮件")
            if mail.attachments > 0 { parts.append("\(mail.searchableAttachments.formatted()) 个附件") }
        }
        return "已索引 " + parts.joined(separator: " · ")
    }
}

/// The two settings pages share presentation, but never share counts or a percentage.
struct SourceIndexProgress: View {
    let model: AppModel
    let source: IndexSource
    let togglePause: () -> Void
    var body: some View {
        let counts = model.counts(for: source)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.sourceStatusLine(source)).font(.system(size: 13, weight: .semibold))
                if counts.pending > 0 { ProgressView(value: counts.fraction).controlSize(.small) }
                else if source == .mail, model.mail?.syncing == true, counts.files == 0 { ProgressView().controlSize(.small) }
                Text(model.sourceDetail(source)).font(.system(size: 11)).foregroundStyle(.secondary)
                if source == .folders, model.counts(for: .mail).pending > 0 {
                    Text("邮件正文和附件的索引进度，请在“邮件”页查看。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if counts.pending > 0 || counts.unfinished > 0 {
                Button(model.status.paused ? "继续全部索引" : "暂停全部索引", action: togglePause)
                    .help("此按钮控制文件夹、邮件和代码的全部索引任务")
            }
        }
    }
}
