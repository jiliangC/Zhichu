import AppKit
import DigUpKit

/// One search result as the panel and the window show it: a file, the part of it that matched, and why.
struct ResultRow: Identifiable, Equatable {
    let id: String          // the file's path
    let url: URL
    let name: String
    let folder: String      // "~/Downloads/Screenshots"
    let kind: FileKind
    let segment: SegmentKind
    let segmentID: Int64
    let loc: Double?        // PDF page, seconds into audio or video, or a stretch of code's first line
    let locEnd: Double?
    /// Code: the line to open at (where the name is defined, or the first line with the query's words).
    let focus: Double?
    let excerpt: String?    // matched words are wrapped in « »
    let matchedMeaning: Bool
    let matchedWords: Bool
    let modified: Date
    let size: Int64
    let info: [String: String]
    /// The query's words (`Searcher.terms`): what the preview highlights on a page or in a passage.
    let terms: [String]

    init(_ hit: SearchHit, terms: [String] = []) {
        id = hit.path
        url = URL(fileURLWithPath: hit.path)
        name = hit.info["mail_subject"] ?? url.lastPathComponent
        // Code says where it is in its repo: "billing/payments".
        if hit.info["mail_id"] != nil {
            folder = [hit.info["mail_account"], hit.info["mail_mailbox"]].compactMap { $0 }.joined(separator: " · ")
        } else if hit.kind == .code, let repo = hit.info["repo"], hit.path.hasPrefix(repo + "/") {
            let parent = (repo as NSString).deletingLastPathComponent
            folder = String(url.deletingLastPathComponent().path.dropFirst(parent.count + 1))
        } else {
            folder = tildePath(url.deletingLastPathComponent().path)
        }
        kind = hit.kind
        segment = hit.segment
        segmentID = hit.segmentID
        loc = hit.loc
        locEnd = hit.locEnd
        focus = hit.focus
        excerpt = hit.excerpt.flatMap { $0.isEmpty ? nil : $0 }
        matchedMeaning = (hit.z ?? 0) >= 2
        matchedWords = hit.keywordRank != nil
        modified = Date(timeIntervalSince1970: hit.modified)
        size = hit.size
        info = hit.info
        self.terms = terms
    }

    /// The name to show: left to right as Finder shows it, also when it starts in Arabic ("ملاحظة.md", not "md.ملاحظة").
    var title: String { "\u{200E}" + name }

    /// The words keyword search found in the excerpt (marked « »), as they're written there.
    var foundWords: [String] {
        guard let excerpt else { return [] }
        var words: [String] = []
        var rest = excerpt[...]
        while let open = rest.firstIndex(of: "«"), let close = rest[open...].firstIndex(of: "»") {
            let word = String(rest[rest.index(after: open)..<close])
            if !word.isEmpty, !words.contains(word) { words.append(word) }
            rest = rest[rest.index(after: close)...]
        }
        return words
    }

    /// The page or moment that matched, as a badge: "p. 3", "0:06", "♪ 0:25" (a video's sound), "L12–40" (code).
    var place: String? {
        guard let loc else { return nil }
        switch segment {
        case .page, .pageImage: return "第 \(Int(loc)) 页"
        case .frame: return Self.clock(loc)
        case .audio: return kind == .video ? "♪ \(Self.clock(loc))" : Self.clock(loc)
        case .lines: return Int(loc) == Int(locEnd ?? loc) ? "L\(Int(loc))" : "L\(Int(loc))–\(Int(locEnd ?? loc))"
        case .cells: return span
        case .chunk: return presentationPage.map { "第 \($0) 页" }
        default: return nil
        }
    }

    /// The lines (or a notebook's cells) of code that matched: "lines 12–40", "cell 3".
    var span: String? {
        guard let loc else { return nil }
        let (first, last) = (Int(loc), Int(locEnd ?? loc))
        switch segment {
        case .lines: return first == last ? "line \(first)" : "lines \(first)–\(last)"
        case .cells: return first == last ? "cell \(first)" : "cells \(first)–\(last)"
        default: return nil
        }
    }

    /// Presentations need their original slide layout rather than the extracted text passage.
    var usesPresentationPreview: Bool { kind == .doc && url.pathExtension.lowercased() == "pptx" }

    /// For PPTX chunks, loc_end stores the original slide number; loc remains the chunk cursor for backfill.
    var presentationPage: Int? {
        guard usesPresentationPreview, segment == .chunk, info["slide_locations"] == "1",
              let locEnd, locEnd >= 1, locEnd <= Double(info["slides"].flatMap(Int.init) ?? 0) else { return nil }
        return Int(locEnd)
    }

    /// What the preview shows: the moment or the page that matched, else the file.
    var previewKey: String {
        "\(id)|\(modified.timeIntervalSince1970.bitPattern)|\(size)|\(segment.rawValue)|\(segmentID)|"
            + "\(loc.map(String.init(describing:)) ?? "")|\(locEnd.map(String.init(describing:)) ?? "")"
    }

    var isMail: Bool { info["mail_id"] != nil || kind == .mail }
    var quickLookURL: URL {
        if isMail, mailAttachment == nil, let path = info["mail_original"] { return URL(fileURLWithPath: path) }
        return url
    }
    var mailAttachment: String? { info["mail_attachment"] }
    var mailDate: Date { Date(timeIntervalSince1970: info["mail_date"].flatMap(Double.init) ?? modified.timeIntervalSince1970) }
    var mailLink: URL? {
        guard let id = info["mail_message_id"], !id.isEmpty else { return nil }
        let normalized = "<" + id.trimmingCharacters(in: CharacterSet(charactersIn: "<>")) + ">"
        return normalized.addingPercentEncoding(withAllowedCharacters: .alphanumerics).flatMap { URL(string: "message://" + $0) }
    }

    var duration: Double? { info["duration"].flatMap(Double.init) }

    /// Why it's here, in a few words: "匹配图片内容", "Matches the frame at 0:06".
    var reason: String {
        if isMail {
            if let attachment = mailAttachment { return "匹配附件《\(attachment)》" + (place.map { "\($0)" } ?? "") }
            return segment == .name ? "匹配邮件主题或发件人" : "匹配邮件正文"
        }
        if segment == .name { return "匹配文件名或拼音" }
        if let page = presentationPage { return "匹配第 \(page) 页幻灯片的内容" }
        guard matchedMeaning else { return matchedWords ? "命中关键词" : "匹配文件名" }
        let place = loc.map(Self.clock) ?? ""
        let page = loc.map { "第 \(Int($0)) 页" } ?? "页面"
        switch segment {
        case .image: return kind == .screenshot ? "匹配截图内容" : "匹配图片内容"
        case .ocr: return "匹配图片中的文字"
        case .frame: return "匹配 \(place) 处的画面"
        case .audio: return kind == .video ? "匹配 \(place) 处的声音" : "匹配 \(place) 处的声音"
        case .page: return "匹配\(page)的文字"
        case .pageImage: return "匹配\(page)"
        case .chunk: return "匹配正文内容"
        case .name: return "匹配文件名"
        case .lines, .cells: return "匹配\(span ?? "代码")"
        }
    }

    /// "Screenshot · Oct 1, 2026 · 1440 × 900 · 2.1 MB", "PDF · … · 463 pages, 120 read so far · 23 MB",
    /// "Python · 63 lines · Oct 1, 2026 · 2 KB"
    var details: String {
        if isMail { return [info["mail_sender"] ?? "", mailDate.formatted(date: .abbreviated, time: .shortened)].joined(separator: " · ") }
        if kind == .code {
            var parts = [CodeExtractor.language(of: url.path)]
            if let cells = info["cells"].flatMap(Int.init) {
                parts.append("\(cells) 个单元")
            } else if let lines = info["lines"].flatMap(Int.init) {
                parts.append("\(lines.formatted()) 行")
            }
            parts.append(modified.formatted(date: .abbreviated, time: .omitted))
            if size > 0 { parts.append(bytes(size)) }
            return parts.joined(separator: " · ")
        }
        var parts = [kind.title, modified.formatted(date: .abbreviated, time: .omitted)]
        if let width = info["width"], let height = info["height"] { parts.append("\(width) × \(height)") }
        // A long file still being read (`Indexer.finishLongFiles`): what isn't read yet can't match.
        let readTo = info["read_to"].flatMap(Int.init)
        if let pages = info["pages"].flatMap(Int.init) {
            parts.append("\(pages) 页" + (readTo.map { "，已读取 \($0) 页" } ?? ""))
        } else if let slides = info["slides"].flatMap(Int.init) {
            parts.append("\(slides) 页幻灯片" + (readTo == nil ? "" : "，部分内容已读取"))
        } else if readTo != nil {
            parts.append("部分内容已读取")
        }
        if let duration { parts.append(Self.clock(duration)) }
        if size > 0 { parts.append(bytes(size)) }
        return parts.joined(separator: " · ")
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds)
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
                             : String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// How results are grouped in the panel, and the kind filters in the window.
enum ResultGroupKind: CaseIterable {
    case screenshots, images, documents, mail, video, audio
    /// Code search's results (the code index; a search of it never shows anything else).
    case code

    /// The kinds of files the main index holds: the window's kind filters, ⌘2 to ⌘6.
    static let files: [ResultGroupKind] = [.screenshots, .images, .documents, .mail, .video, .audio]

    init(_ kind: FileKind) {
        switch kind {
        case .screenshot: self = .screenshots
        case .image: self = .images
        case .pdf, .doc: self = .documents
        case .mail: self = .mail
        case .video: self = .video
        case .audio: self = .audio
        case .code: self = .code
        }
    }

    var title: String {
        switch self {
        case .screenshots: "截图"
        case .images: "图片"
        case .documents: "文档"
        case .mail: "邮件"
        case .video: "视频"
        case .audio: "音频"
        case .code: "代码"
        }
    }

    var symbol: String {
        switch self {
        case .screenshots: FileKind.screenshot.symbol
        case .images: FileKind.image.symbol
        case .documents: FileKind.doc.symbol
        case .mail: FileKind.mail.symbol
        case .video: FileKind.video.symbol
        case .audio: FileKind.audio.symbol
        case .code: FileKind.code.symbol
        }
    }

    var kinds: Set<FileKind> {
        switch self {
        case .screenshots: [.screenshot]
        case .images: [.image]
        case .documents: [.pdf, .doc]
        case .mail: [.mail]
        case .video: [.video]
        case .audio: [.audio]
        case .code: [.code]
        }
    }
}

struct ResultGroup: Identifiable, Equatable {
    let kind: ResultGroupKind
    let rows: [ResultRow]
    /// Strong results of this kind, shown or not (the panel shows a few).
    var total: Int
    var id: ResultGroupKind { kind }
}

/// Search results the way they're shown: the strong ones grouped by kind (the best hit's group first, as many rows per
/// group as there's room for), and the weaker ones (below half the top score) folded underneath.
struct ResultSet: Equatable {
    var groups: [ResultGroup] = []
    /// The strong ones in score order (the window's grid; the panel shows `groups`).
    var ranked: [ResultRow] = []
    var weaker: [ResultRow] = []

    static let empty = ResultSet()

    init() {}

    init(_ hits: [SearchHit], query: String = "", rowsPerGroup: Int = .max) {
        let strong = Searcher.strongCount(hits)
        let terms = Searcher.terms(query)
        var order: [ResultGroupKind] = []
        var byGroup: [ResultGroupKind: [ResultRow]] = [:]
        ranked = hits.prefix(strong).map { ResultRow($0, terms: terms) }
        for row in ranked {
            let group = row.isMail ? ResultGroupKind.mail : ResultGroupKind(row.kind)
            if byGroup[group] == nil { order.append(group) }
            byGroup[group, default: []].append(row)
        }
        groups = order.map {
            ResultGroup(kind: $0, rows: Array(byGroup[$0]!.prefix(rowsPerGroup)), total: byGroup[$0]!.count)
        }
        weaker = hits.dropFirst(strong).map { ResultRow($0, terms: terms) }
    }

    var strongRows: [ResultRow] { groups.flatMap(\.rows) }
    var isEmpty: Bool { groups.isEmpty && weaker.isEmpty }
    var count: Int { strongRows.count + weaker.count }
}

extension FileKind {
    var title: String {
        switch self {
        case .screenshot: "截图"
        case .image: "图片"
        case .pdf: "PDF"
        case .doc: "文档"
        case .mail: "邮件"
        case .audio: "音频"
        case .video: "视频"
        case .code: "代码"
        }
    }

    var symbol: String {
        switch self {
        case .screenshot: "camera.viewfinder"
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .doc: "doc.text"
        case .mail: "envelope"
        case .audio: "waveform"
        case .video: "film"
        case .code: "chevron.left.forwardslash.chevron.right"
        }
    }
}
