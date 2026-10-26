//
// Author: Jeffrey Stedfast <jestedfa@microsoft.com>
//
// Copyright (c) 2013-2026 .NET Foundation and Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

//
// HtmlTagId.swift
//
// Ported from MimeKit (C#) to Swift.
//

/// HTML tag identifiers.
///
/// An enumeration of known HTML tag identifiers used for efficient tag comparison
/// without string matching.
public enum HtmlTagId: String, Sendable {
    /// An unknown HTML tag identifier.
    case unknown = ""

    /// The HTML `<a>` tag.
    case a = "a"
    /// The HTML `<abbr>` tag.
    case abbr = "abbr"
    /// The HTML `<acronym>` tag.
    case acronym = "acronym"
    /// The HTML `<address>` tag.
    case address = "address"
    /// The HTML `<applet>` tag.
    case applet = "applet"
    /// The HTML `<area>` tag.
    case area = "area"
    /// The HTML `<article>` tag.
    case article = "article"
    /// The HTML `<aside>` tag.
    case aside = "aside"
    /// The HTML `<audio>` tag.
    case audio = "audio"
    /// The HTML `<b>` tag.
    case b = "b"
    /// The HTML `<base>` tag.
    case base = "base"
    /// The HTML `<basefont>` tag.
    case baseFont = "basefont"
    /// The HTML `<bdi>` tag.
    case bdi = "bdi"
    /// The HTML `<bdo>` tag.
    case bdo = "bdo"
    /// The HTML `<bgsound>` tag.
    case bgSound = "bgsound"
    /// The HTML `<big>` tag.
    case big = "big"
    /// The HTML `<blink>` tag.
    case blink = "blink"
    /// The HTML `<blockquote>` tag.
    case blockQuote = "blockquote"
    /// The HTML `<body>` tag.
    case body = "body"
    /// The HTML `<br>` tag.
    case br = "br"
    /// The HTML `<button>` tag.
    case button = "button"
    /// The HTML `<canvas>` tag.
    case canvas = "canvas"
    /// The HTML `<caption>` tag.
    case caption = "caption"
    /// The HTML `<center>` tag.
    case center = "center"
    /// The HTML `<cite>` tag.
    case cite = "cite"
    /// The HTML `<code>` tag.
    case code = "code"
    /// The HTML `<col>` tag.
    case col = "col"
    /// The HTML `<colgroup>` tag.
    case colGroup = "colgroup"
    /// The HTML `<command>` tag.
    case command = "command"
    /// The HTML comment tag.
    case comment = "!"
    /// The HTML `<datalist>` tag.
    case dataList = "datalist"
    /// The HTML `<dd>` tag.
    case dd = "dd"
    /// The HTML `<del>` tag.
    case del = "del"
    /// The HTML `<details>` tag.
    case details = "details"
    /// The HTML `<dfn>` tag.
    case dfn = "dfn"
    /// The HTML `<dialog>` tag.
    case dialog = "dialog"
    /// The HTML `<dir>` tag.
    case dir = "dir"
    /// The HTML `<div>` tag.
    case div = "div"
    /// The HTML `<dl>` tag.
    case dl = "dl"
    /// The HTML `<dt>` tag.
    case dt = "dt"
    /// The HTML `<em>` tag.
    case em = "em"
    /// The HTML `<embed>` tag.
    case embed = "embed"
    /// The HTML `<fieldset>` tag.
    case fieldSet = "fieldset"
    /// The HTML `<figcaption>` tag.
    case figCaption = "figcaption"
    /// The HTML `<figure>` tag.
    case figure = "figure"
    /// The HTML `<font>` tag.
    case font = "font"
    /// The HTML `<footer>` tag.
    case footer = "footer"
    /// The HTML `<form>` tag.
    case form = "form"
    /// The HTML `<frame>` tag.
    case frame = "frame"
    /// The HTML `<frameset>` tag.
    case frameSet = "frameset"
    /// The HTML `<h1>` tag.
    case h1 = "h1"
    /// The HTML `<h2>` tag.
    case h2 = "h2"
    /// The HTML `<h3>` tag.
    case h3 = "h3"
    /// The HTML `<h4>` tag.
    case h4 = "h4"
    /// The HTML `<h5>` tag.
    case h5 = "h5"
    /// The HTML `<h6>` tag.
    case h6 = "h6"
    /// The HTML `<head>` tag.
    case head = "head"
    /// The HTML `<header>` tag.
    case header = "header"
    /// The HTML `<hr>` tag.
    case hr = "hr"
    /// The HTML `<html>` tag.
    case html = "html"
    /// The HTML `<i>` tag.
    case i = "i"
    /// The HTML `<iframe>` tag.
    case iframe = "iframe"
    /// The HTML `<img>` tag.
    case image = "img"
    /// The HTML `<input>` tag.
    case input = "input"
    /// The HTML `<ins>` tag.
    case ins = "ins"
    /// The HTML `<isindex>` tag.
    case isIndex = "isindex"
    /// The HTML `<kbd>` tag.
    case kbd = "kbd"
    /// The HTML `<keygen>` tag.
    case keygen = "keygen"
    /// The HTML `<label>` tag.
    case label = "label"
    /// The HTML `<legend>` tag.
    case legend = "legend"
    /// The HTML `<li>` tag.
    case li = "li"
    /// The HTML `<link>` tag.
    case link = "link"
    /// The HTML `<listing>` tag.
    case listing = "listing"
    /// The HTML `<main>` tag.
    case main = "main"
    /// The HTML `<map>` tag.
    case map = "map"
    /// The HTML `<mark>` tag.
    case mark = "mark"
    /// The HTML `<marquee>` tag.
    case marquee = "marquee"
    /// The HTML `<menu>` tag.
    case menu = "menu"
    /// The HTML `<menuitem>` tag.
    case menuitem = "menuitem"
    /// The HTML `<meta>` tag.
    case meta = "meta"
    /// The HTML `<meter>` tag.
    case meter = "meter"
    /// The HTML `<nav>` tag.
    case nav = "nav"
    /// The HTML `<nextid>` tag.
    case nextId = "nextid"
    /// The HTML `<nobr>` tag.
    case noBr = "nobr"
    /// The HTML `<noembed>` tag.
    case noEmbed = "noembed"
    /// The HTML `<noframes>` tag.
    case noFrames = "noframes"
    /// The HTML `<noscript>` tag.
    case noScript = "noscript"
    /// The HTML `<object>` tag.
    case object = "object"
    /// The HTML `<ol>` tag.
    case ol = "ol"
    /// The HTML `<optgroup>` tag.
    case optGroup = "optgroup"
    /// The HTML `<option>` tag.
    case option = "option"
    /// The HTML `<output>` tag.
    case output = "output"
    /// The HTML `<p>` tag.
    case p = "p"
    /// The HTML `<param>` tag.
    case param = "param"
    /// The HTML `<plaintext>` tag.
    case plainText = "plaintext"
    /// The HTML `<pre>` tag.
    case pre = "pre"
    /// The HTML `<progress>` tag.
    case progress = "progress"
    /// The HTML `<q>` tag.
    case q = "q"
    /// The HTML `<rp>` tag.
    case rp = "rp"
    /// The HTML `<rt>` tag.
    case rt = "rt"
    /// The HTML `<ruby>` tag.
    case ruby = "ruby"
    /// The HTML `<s>` tag.
    case s = "s"
    /// The HTML `<samp>` tag.
    case samp = "samp"
    /// The HTML `<script>` tag.
    case script = "script"
    /// The HTML `<section>` tag.
    case section = "section"
    /// The HTML `<select>` tag.
    case select = "select"
    /// The HTML `<small>` tag.
    case small = "small"
    /// The HTML `<source>` tag.
    case source = "source"
    /// The HTML `<span>` tag.
    case span = "span"
    /// The HTML `<strike>` tag.
    case strike = "strike"
    /// The HTML `<strong>` tag.
    case strong = "strong"
    /// The HTML `<style>` tag.
    case style = "style"
    /// The HTML `<sub>` tag.
    case sub = "sub"
    /// The HTML `<summary>` tag.
    case summary = "summary"
    /// The HTML `<sup>` tag.
    case sup = "sup"
    /// The HTML `<table>` tag.
    case table = "table"
    /// The HTML `<tbody>` tag.
    case tbody = "tbody"
    /// The HTML `<td>` tag.
    case td = "td"
    /// The HTML `<textarea>` tag.
    case textArea = "textarea"
    /// The HTML `<tfoot>` tag.
    case tfoot = "tfoot"
    /// The HTML `<th>` tag.
    case th = "th"
    /// The HTML `<thead>` tag.
    case thead = "thead"
    /// The HTML `<time>` tag.
    case time = "time"
    /// The HTML `<title>` tag.
    case title = "title"
    /// The HTML `<tr>` tag.
    case tr = "tr"
    /// The HTML `<track>` tag.
    case track = "track"
    /// The HTML `<tt>` tag.
    case tt = "tt"
    /// The HTML `<u>` tag.
    case u = "u"
    /// The HTML `<ul>` tag.
    case ul = "ul"
    /// The HTML `<var>` tag.
    case variable = "var"
    /// The HTML `<video>` tag.
    case video = "video"
    /// The HTML `<wbr>` tag.
    case wbr = "wbr"
    /// The HTML `<xml>` tag.
    case xml = "xml"
    /// The HTML `<xmp>` tag.
    case xmp = "xmp"
}

/// Utility methods for ``HtmlTagId`` operations.
///
/// Provides methods for converting between tag names and identifiers,
/// and for querying tag properties.
public enum HtmlTagIdUtils {
    private static let nameToId: [String: HtmlTagId] = {
        var map: [String: HtmlTagId] = [:]
        // We can use the RawValue if it matches the name
        // However, some have special names or we want to be safe
        let allTags: [HtmlTagId] = [
            .a, .abbr, .acronym, .address, .applet, .area, .article, .aside, .audio,
            .b, .base, .baseFont, .bdi, .bdo, .bgSound, .big, .blink, .blockQuote,
            .body, .br, .button, .canvas, .caption, .center, .cite, .code, .col,
            .colGroup, .command, .comment, .dataList, .dd, .del, .details, .dfn,
            .dialog, .dir, .div, .dl, .dt, .em, .embed, .fieldSet, .figCaption,
            .figure, .font, .footer, .form, .frame, .frameSet, .h1, .h2, .h3,
            .h4, .h5, .h6, .head, .header, .hr, .html, .i, .iframe, .image,
            .input, .ins, .isIndex, .kbd, .keygen, .label, .legend, .li, .link,
            .listing, .main, .map, .mark, .marquee, .menu, .menuitem, .meta,
            .meter, .nav, .nextId, .noBr, .noEmbed, .noFrames, .noScript, .object,
            .ol, .optGroup, .option, .output, .p, .param, .plainText, .pre,
            .progress, .q, .rp, .rt, .ruby, .s, .samp, .script, .section,
            .select, .small, .source, .span, .strike, .strong, .style, .sub,
            .summary, .sup, .table, .tbody, .td, .textArea, .tfoot, .th,
            .thead, .time, .title, .tr, .track, .tt, .u, .ul, .variable,
            .video, .wbr, .xml, .xmp
        ]
        for id in allTags {
            map[id.rawValue] = id
        }
        return map
    }()

    private static let emptyElements: Set<HtmlTagId> = [
        .area, .base, .br, .col, .command, .embed, .hr, .image, .input, .keygen,
        .link, .meta, .param, .source, .track, .wbr
    ]

    /// Converts the enum value into the equivalent tag name.
    ///
    /// - Parameter id: The enum value.
    /// - Returns: The tag name.
    public static func toHtmlTagName(_ id: HtmlTagId) -> String {
        if id == .unknown {
            return ""
        }
        return id.rawValue
    }

    /// Converts the tag name into the equivalent tag id.
    ///
    /// - Parameter name: The tag name.
    /// - Returns: The tag id.
    public static func toHtmlTagId(_ name: String) -> HtmlTagId {
        if name.isEmpty {
            return .unknown
        }
        if name.hasPrefix("!") {
            return .comment
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .unknown
        }
        if let mapped = nameToId[trimmed.lowercased()] {
            return mapped
        }
        return .unknown
    }

    /// Determines whether the HTML tag is an empty element.
    ///
    /// Empty elements are self-closing tags like `<br>`, `<img>`, etc.
    ///
    /// - Parameter id: The tag identifier.
    /// - Returns: `true` if the tag is an empty element; otherwise, `false`.
    public static func isEmptyElement(_ id: HtmlTagId) -> Bool {
        emptyElements.contains(id)
    }

    /// Determines whether the HTML tag is a formatting element.
    ///
    /// Formatting elements are inline elements that affect text formatting,
    /// such as `<b>`, `<i>`, `<em>`, `<strong>`, etc.
    ///
    /// - Parameter id: The HTML tag identifier.
    /// - Returns: `true` if the HTML tag is a formatting element; otherwise, `false`.
    public static func isFormattingElement(_ id: HtmlTagId) -> Bool {
        switch id {
        case .a, .b, .big, .code, .em, .font, .i, .noBr, .s, .small, .strike, .strong, .tt, .u:
            return true
        default:
            return false
        }
    }
}

/// ``HtmlTagId`` extension methods.
public extension HtmlTagId {
    /// Gets the HTML tag name for this identifier.
    var htmlTagName: String {
        HtmlTagIdUtils.toHtmlTagName(self)
    }

    /// Determines whether this tag is an empty element.
    ///
    /// Empty elements are self-closing tags like `<br>`, `<img>`, etc.
    var isEmptyElement: Bool {
        HtmlTagIdUtils.isEmptyElement(self)
    }

    /// Determines whether this tag is a formatting element.
    ///
    /// Formatting elements are inline elements that affect text formatting.
    var isFormattingElement: Bool {
        HtmlTagIdUtils.isFormattingElement(self)
    }

    /// Creates an ``HtmlTagId`` from a tag name string.
    ///
    /// - Parameter tagName: The tag name.
    /// - Returns: The corresponding tag identifier, or ``HtmlTagId/unknown`` if not recognized.
    static func from(tagName: String) -> HtmlTagId {
        HtmlTagIdUtils.toHtmlTagId(tagName)
    }
}