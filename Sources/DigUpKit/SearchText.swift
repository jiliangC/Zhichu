import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Text the way keyword search keeps it and matches it, so that a word is found however it was typed or extracted.
public enum SearchText {
    /// NFKC (Arabic presentation forms and ligatures become plain letters, full-width becomes ASCII, and Bengali's
    /// two spellings of "ো" become one), invisible formatting characters dropped (Bengali's zero-width joiners,
    /// direction marks), and Arabic the way people type it: no tatweel, no short-vowel marks, one alef.
    public static func normalized(_ text: String) -> String {
        let compatible = text.precomposedStringWithCompatibilityMapping
        var scalars = String.UnicodeScalarView()
        for scalar in compatible.unicodeScalars {
            switch scalar.value {
            case 0x200B: scalars.append(" ")   // zero-width space: a word break (Thai, Khmer)
            case 0x00AD, 0x061C, 0x200C...0x200F, 0x202A...0x202E, 0x2060...0x2064, 0x2066...0x2069, 0xFEFF:
                continue                         // joiners, direction marks, soft hyphen, BOM
            case 0x0640, 0x064B...0x065F, 0x0670:
                continue                         // tatweel; harakat and the dagger alef
            case 0x0622, 0x0623, 0x0625, 0x0671:
                scalars.append("\u{0627}")       // alef with hamza or madda, wasla → alef
            default:
                scalars.append(scalar)
            }
        }
        let result = String(scalars)
        // Match simplified/traditional forms through one search representation. Excerpts retain original text.
        return containsHan(result)
            ? result.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? result : result
    }

    /// True for words of scripts that attach endings to words (Bengali, Hindi, Arabic): keyword search matches them as
    /// prefixes, so "কুমির" finds "কুমিরও" and "مدرس" finds "مدرسة".
    public static func inflects(_ word: String) -> Bool {
        word.unicodeScalars.contains { Script.indic.contains($0.value) || Script.arabic.contains($0.value) }
    }

    /// Whether text says something in words: at least a fifth of what isn't space is letters (marks count, such as
    /// Bengali vowel signs). A data dump or a table of numbers isn't, and gets keyword search only: a meaning vector of
    /// digits matches nothing anyone would describe. On the testbed (2026-10-09) real pages and chunks had 30% letters
    /// or more; a 970,000-character dump of numbers saved as .txt had none, and would have been 607 vectors.
    public static func hasWords(_ text: String) -> Bool {
        var letters = 0, others = 0
        for scalar in text.unicodeScalars where !CharacterSet.whitespacesAndNewlines.contains(scalar) {
            if CharacterSet.letters.contains(scalar) { letters += 1 } else { others += 1 }
        }
        return letters > 0 && letters * 4 >= others
    }

    /// Enough prose for a vector: `hasWords`, and at least four words with a letter in them. A stub (`DEBUG=true`,
    /// `root = true`, a two-line .gitignore) passes the letters test and then wins generic queries on meaning alone,
    /// since text that short collapses toward the model's generic centre; its words are still found by keyword.
    public static func hasProse(_ text: String) -> Bool {
        guard hasWords(text) else { return false }
        // Chinese prose has no whitespace. Admit sentences while keeping short labels out of vectors.
        if text.unicodeScalars.filter({ isHan($0) }).count >= 12 { return true }
        var words = 0
        for word in text.split(whereSeparator: \.isWhitespace) where word.unicodeScalars.contains(where: CharacterSet.letters.contains) {
            words += 1
            if words >= 4 { return true }
        }
        return false
    }

    /// Han characters become ordered FTS tokens. Keep the original separately for readable excerpts.
    public static func indexText(_ text: String) -> String {
        var result = ""
        for scalar in normalized(text).unicodeScalars {
            if isHan(scalar) { result += " " + String(scalar) + " " }
            else { result.unicodeScalars.append(scalar) }
        }
        return result
    }

    public static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isHan)
    }

    /// Pinyin aliases belong to short file names, never to the full document body.
    public static func filenameKeywords(_ name: String) -> String {
        indexText(name) + " " + pinyinAliases(name).joined(separator: " ")
    }

    /// Whole-name keys distinguish an intentional filename/pinyin lookup from an unrelated semantic match.
    public static func filenameLookupKeys(_ name: String) -> Set<String> {
        Set(([name, (name as NSString).deletingPathExtension] + pinyinAliases(name)).map(lookupKey))
    }

    public static func lookupKey(_ text: String) -> String {
        normalized(text).lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func pinyinAliases(_ name: String) -> [String] {
        guard containsHan(name) else { return [] }
        let stem = normalized((name as NSString).deletingPathExtension)
        let corrected = phrasePinyin(stem)
        var seen = Set<String>(), aliases: [String] = []
        // Keep the old system reading too, so upgrading never removes an alias users already learned.
        for source in [stem, corrected] {
            guard let latin = source.applyingTransform(.toLatin, reverse: false)?
                .applyingTransform(.stripDiacritics, reverse: false) else { continue }
            let words = latin.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            for alias in [words.joined(separator: " "), words.joined(), words.compactMap(\.first).map(String.init).joined()]
                where !alias.isEmpty && seen.insert(alias).inserted { aliases.append(alias) }
        }
        return aliases
    }

    /// A small, explicit common-word lexicon fixes ambiguous system readings without enumerating every
    /// possible reading of every character (which creates many false filename matches).
    private static let pinyinPhrases: [(String, String)] = {
        let phrases: [String: String] = [
        "目的地": "mu di di", "地铁": "di tie", "地图": "di tu", "地址": "di zhi", "地方": "di fang",
        "地产": "di chan", "场地": "chang di", "地区": "di qu", "土地": "tu di", "地理": "di li",
        "当地": "dang di", "出行": "chu xing", "行程": "xing cheng", "旅行": "lu xing",
        "银行": "yin hang", "行业": "hang ye", "行号": "hang hao", "行为": "xing wei",
        "执行": "zhi xing", "运行": "yun xing", "排行": "pai hang", "重庆": "chong qing",
        "重复": "chong fu", "重新": "chong xin", "重要": "zhong yao", "重量": "zhong liang",
        "音乐": "yin yue", "乐器": "yue qi", "快乐": "kuai le", "长大": "zhang da",
        "长江": "chang jiang", "长度": "chang du", "长文": "chang wen",
        ]
        return phrases.sorted { lhs, rhs in
            if lhs.key.count != rhs.key.count { return lhs.key.count > rhs.key.count }
            return lhs.key < rhs.key
        }.map { ($0.key, $0.value) }
    }()

    private static func phrasePinyin(_ text: String) -> String {
        var cursor = text.startIndex, result = "", buffer = ""
        while cursor < text.endIndex {
            if let (word, pinyin) = pinyinPhrases.first(where: { text[cursor...].hasPrefix($0.0) }) {
                result += buffer + " " + pinyin + " "
                buffer = ""
                cursor = text.index(cursor, offsetBy: word.count)
            } else {
                buffer.append(text[cursor])
                cursor = text.index(after: cursor)
            }
        }
        return result + buffer
    }

    /// Apple's word segmentation for Chinese; other scripts keep the upstream tokenization.
    public static func queryWords(_ text: String) -> [String] {
        let text = normalized(text).lowercased()
        guard containsHan(text) else {
            return text.components(separatedBy: CharacterSet.alphanumerics.inverted)
        }
        #if canImport(NaturalLanguage)
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map { String(text[$0]) }
        #else
        return text.components(separatedBy: CharacterSet.alphanumerics.inverted)
        #endif
    }

    private static func isHan(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x323AF: true
        default: false
        }
    }

    /// Where `word` is in `text` as keyword search would find it (normalized, ignoring case and accents), as ranges of
    /// the text as it's written: whole words, and for a word of a language that attaches endings, the whole word it
    /// starts ("কুমির" marks all of "কুমিরের"). For marking matches on what's shown (it never splits a letter from its
    /// vowel sign).
    public static func matches(of word: String, in text: String) -> [Range<String.Index>] {
        let needle = normalized(word).lowercased()
        guard !needle.isEmpty else { return [] }
        let folded = Folded(text)
        let haystack = folded.text as NSString
        let prefix = inflects(word)
        var found: [Range<String.Index>] = []
        var searchRange = NSRange(location: 0, length: haystack.length)
        while found.count < 500 {
            let hit = haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
            guard hit.location != NSNotFound else { break }
            searchRange = NSRange(location: hit.upperBound, length: haystack.length - hit.upperBound)
            guard var range = folded.original(hit) else { continue }
            if !containsHan(word), range.lowerBound > text.startIndex, isWordCharacter(text[text.index(before: range.lowerBound)]) {
                continue
            }
            if !containsHan(word), range.upperBound < text.endIndex, isWordCharacter(text[range.upperBound]) {
                guard prefix else { continue }
                var end = range.upperBound
                while end < text.endIndex, isWordCharacter(text[end]) { end = text.index(after: end) }
                range = range.lowerBound..<end
            }
            if let last = found.last, last.overlaps(range) { continue }
            found.append(range)
        }
        return found
    }

    /// One line from `text` around the first of `terms` it has, the terms marked « » as SQLite's snippet() marks them:
    /// the excerpt of a keyword match, from the text as it's written. Nil when none of the terms is in it.
    public static func snippet(_ text: String, terms: [String], words: Int = 12) -> String? {
        let marks = terms.flatMap { matches(of: $0, in: text) }.sorted { $0.lowerBound < $1.lowerBound }
        guard let first = marks.first else { return nil }
        // About `words` words, starting a few before the first match.
        let chinese = containsHan(text)
        var start = first.lowerBound, before = 0, beforeCharacters = 0
        while start > text.startIndex, before < words / 3, !chinese || beforeCharacters < 40 {
            start = text.index(before: start)
            beforeCharacters += 1
            if text[start].isWhitespace, start < first.lowerBound, !text[text.index(after: start)].isWhitespace {
                before += 1
            }
        }
        if start > text.startIndex || text[start].isWhitespace { start = text.index(after: start) }
        var end = first.upperBound, after = 0, afterCharacters = 0
        while end < text.endIndex, after < words - before, !chinese || afterCharacters < 100 {
            if text[end].isWhitespace { after += 1 }
            end = text.index(after: end)
            afterCharacters += 1
        }
        var out = start > text.startIndex ? "…" : ""
        var cursor = start
        for mark in marks where mark.lowerBound >= start && mark.upperBound <= end && mark.lowerBound >= cursor {
            out += text[cursor..<mark.lowerBound] + "«" + text[mark] + "»"
            cursor = mark.upperBound
        }
        out += text[cursor..<end] + (end < text.endIndex ? "…" : "")
        return out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    /// `text` normalized one character at a time, remembering where each piece came from.
    private struct Folded {
        let text: String
        /// For each UTF-16 unit of `text`, the original character it came from.
        private let origin: [String.Index]
        private let source: String

        init(_ source: String) {
            self.source = source
            var text = "", origin: [String.Index] = []
            var index = source.startIndex
            for character in source {
                let piece = normalized(String(character)).lowercased()
                text += piece
                origin += Array(repeating: index, count: piece.utf16.count)
                index = source.index(after: index)
            }
            self.text = text
            self.origin = origin
        }

        /// The characters of the source that `range` (in `text`) came from.
        func original(_ range: NSRange) -> Range<String.Index>? {
            guard range.length > 0, range.upperBound <= origin.count else { return nil }
            let first = origin[range.location], last = origin[range.upperBound - 1]
            return first..<source.index(after: last)
        }
    }
}

/// Words to search for in a PDF so its page is among the matches (Preview, opened the way Spotlight opens documents,
/// fills its search with them and lists the matches by page).
public enum Landmark {
    /// `texts`: the PDF's own text (what the app searches, as PDFKit reads it) of pages 1 through `page`. The first of
    /// `words` that's on that page, spelled as the page spells it, preferring one that isn't on an earlier page. Nil for
    /// page 1 (it opens there anyway), or when none of the words is on it.
    public static func find(page: Int, texts: [String], words: [String]) -> String? {
        guard page > 1, texts.count >= page else { return nil }
        let target = texts[page - 1]
        let before = texts.prefix(page - 1).map { SearchText.normalized($0).lowercased() }
        let onPage = words.filter { $0.count >= 3 || (SearchText.containsHan($0) && $0.count >= 2) }.compactMap { word in
            SearchText.matches(of: word, in: target).first.map { String(target[$0]) }
        }
        return onPage.first { word in !before.contains { $0.contains(SearchText.normalized(word).lowercased()) } }
            ?? onPage.first
    }
}

enum Script {
    static let indic: ClosedRange<UInt32> = 0x0900...0x0DFF
    static let arabic: ClosedRange<UInt32> = 0x0600...0x06FF
}

/// What's wrong with the text PDFKit read from a page, when the page's text layer can't be used as it is.
enum PageTextProblem: Equatable {
    /// Bengali or Hindi read in glyph order: vowel signs ahead of their consonants, conjuncts lost ("চুক্তিপত্র" reads
    /// "চিপ"). PDFKit reads most Bengali PDFs this way, whatever made them (Quartz, WebKit, Chrome). The page is used
    /// as a picture instead (Apple's OCR doesn't read Bengali).
    case glyphOrder
    /// Arabic letters lost where the font drew a lam ligature: the article's lam goes with the ligature, leaving a bare
    /// alef before a "?" or "." ("الأردن" reads "ا?ردن", "المبيعات" "ا.بيعات"). The page is read again by OCR. A bare
    /// alef, not أ: "أ.د." (Prof. Dr.) and "ذ.م.م" (LLC) are real abbreviations.
    case lostLetters

    static func check(_ text: String) -> PageTextProblem? {
        let text = text.precomposedStringWithCanonicalMapping
        var vowelSigns = 0, misplaced = 0, lostLetters = 0
        var previous: Unicode.Scalar = " ", beforePrevious: Unicode.Scalar = " "
        for scalar in text.unicodeScalars {
            if isIndicVowelSign(scalar.value) {
                vowelSigns += 1
                if !isIndicConsonantOrNukta(previous.value) { misplaced += 1 }
            }
            if beforePrevious == "\u{0627}", "?.\u{FFFD}".unicodeScalars.contains(previous),
               Script.arabic.contains(scalar.value), scalar.properties.isAlphabetic {
                lostLetters += 1
            }
            beforePrevious = previous
            previous = scalar
        }
        if vowelSigns >= 10, misplaced * 20 >= vowelSigns { return .glyphOrder }
        if lostLetters >= 2 { return .lostLetters }
        return nil
    }

    /// Dependent vowel signs of Bengali and Devanagari: in a real word, each follows a consonant (or its nukta).
    private static func isIndicVowelSign(_ value: UInt32) -> Bool {
        switch value {
        case 0x09BE...0x09C4, 0x09C7, 0x09C8, 0x09CB, 0x09CC, 0x09D7, 0x09E2, 0x09E3: true
        case 0x093A, 0x093B, 0x093E...0x094C, 0x094E, 0x094F, 0x0955...0x0957, 0x0962, 0x0963: true
        default: false
        }
    }

    private static func isIndicConsonantOrNukta(_ value: UInt32) -> Bool {
        switch value {
        case 0x0995...0x09B9, 0x09BC, 0x09CE, 0x09DC, 0x09DD, 0x09DF, 0x09F0, 0x09F1: true
        case 0x0915...0x0939, 0x093C, 0x0958...0x095F, 0x0979...0x097F: true
        default: false
        }
    }
}
