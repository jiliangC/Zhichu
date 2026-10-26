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
// DateUtils.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// Internal flags used during date token parsing.
private struct DateTokenFlags: OptionSet {
    let rawValue: UInt8

    static let none = DateTokenFlags([])
    static let nonNumeric = DateTokenFlags(rawValue: 1 << 0)
    static let nonWeekday = DateTokenFlags(rawValue: 1 << 1)
    static let nonMonth = DateTokenFlags(rawValue: 1 << 2)
    static let nonTime = DateTokenFlags(rawValue: 1 << 3)
    static let nonAlphaZone = DateTokenFlags(rawValue: 1 << 4)
    static let nonNumericZone = DateTokenFlags(rawValue: 1 << 5)
    static let hasColon = DateTokenFlags(rawValue: 1 << 6)
    static let hasSign = DateTokenFlags(rawValue: 1 << 7)
}

/// Internal representation of a date token during parsing.
private struct DateToken {
    let flags: DateTokenFlags
    let start: Int
    let length: Int

    var isNumeric: Bool { !flags.contains(.nonNumeric) }
    var isWeekday: Bool { !flags.contains(.nonWeekday) }
    var isMonth: Bool { !flags.contains(.nonMonth) }
    var isTimeOfDay: Bool { !flags.contains(.nonTime) && flags.contains(.hasColon) }
    var isNumericZone: Bool { !flags.contains(.nonNumericZone) && flags.contains(.hasSign) }
    var isAlphaZone: Bool { !flags.contains(.nonAlphaZone) }
    var isTimeZone: Bool { isNumericZone || isAlphaZone }
}

/// Utility methods to parse and format RFC 2822 date strings.
///
/// `DateUtils` provides methods for parsing date strings from MIME message headers
/// (such as the Date header) and formatting dates for use in outgoing messages.
/// The parser is tolerant of common variations and malformed dates found in
/// real-world email messages.
///
/// ## Parsing Dates
///
/// The ``tryParse(_:date:)-95tts`` methods attempt to parse dates from various formats:
///
/// ```swift
/// var date: DateTimeOffset?
/// if DateUtils.tryParse("Mon, 15 Mar 2024 14:30:00 -0500", date: &date) {
///     print(date!)  // Successfully parsed
/// }
///
/// // Also handles non-standard formats
/// DateUtils.tryParse("15-Mar-2024 14:30:00 EST", date: &date)
/// DateUtils.tryParse("March 15, 2024 2:30 PM", date: &date)
/// ```
///
/// ## Formatting Dates
///
/// Format dates for use in MIME headers using RFC 2822 format:
///
/// ```swift
/// let date = DateTimeOffset.now()
/// let formatted = DateUtils.formatDate(date)
/// // "Mon, 15 Mar 2024 14:30:00 -0500"
/// ```
///
/// ## Supported Formats
///
/// The parser handles many common date formats including:
/// - RFC 2822: `Mon, 15 Mar 2024 14:30:00 -0500`
/// - RFC 822: `15 Mar 24 14:30:00 EST`
/// - Various non-standard formats used by mail clients
/// - Dates with or without weekday names
/// - 12-hour time with AM/PM
/// - Numeric and alphabetic timezone designations
public enum DateUtils {
    private static let monthCharacters = "JanuaryFebruaryMarchAprilMayJuneJulyAugustSeptemberOctoberNovemberDecember"
    private static let weekdayCharacters = "SundayMondayTuesdayWednesdayThursdayFridaySaturday"
    private static let alphaZoneCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let numericZoneCharacters = "+-0123456789"
    private static let numericCharacters = "0123456789"
    private static let timeCharacters = "0123456789:"

    private static let months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ]

    private static let weekDays = [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
    ]

    private static let timezones: [String: Int] = [
        "UT": 0, "UTC": 0, "GMT": 0,
        "EDT": -400, "EST": -500,
        "CDT": -500, "CST": -600,
        "MDT": -600, "MST": -700,
        "PDT": -700, "PST": -800,
        "A": 100, "B": 200, "C": 300,
        "D": 400, "E": 500, "F": 600,
        "G": 700, "H": 800, "I": 900,
        "K": 1000, "L": 1100, "M": 1200,
        "N": -100, "O": -200, "P": -300,
        "Q": -400, "R": -500, "S": -600,
        "T": -700, "U": -800, "V": -900,
        "W": -1000, "X": -1100, "Y": -1200,
        "Z": 0,
        "JST": 900, "KST": 900
    ]

    private static let datetok: [DateTokenFlags] = {
        var table = Array(repeating: DateTokenFlags.none, count: 256)
        for c in 0..<256 {
            guard let scalar = UnicodeScalar(c) else {
                continue
            }
            let ch = Character(scalar)
            let upper = String(ch).uppercased()
            let lower = String(ch).lowercased()

            if !numericZoneCharacters.contains(ch) {
                table[c].insert(.nonNumericZone)
            }
            if !alphaZoneCharacters.contains(ch) {
                table[c].insert(.nonAlphaZone)
            }

            if !weekdayCharacters.contains(upper) && !weekdayCharacters.contains(lower) {
                table[c].insert(.nonWeekday)
            }
            if !numericCharacters.contains(ch) {
                table[c].insert(.nonNumeric)
            }
            if !monthCharacters.contains(upper) && !monthCharacters.contains(lower) {
                table[c].insert(.nonMonth)
            }
            if !timeCharacters.contains(ch) {
                table[c].insert(.nonTime)
            }
        }

        table[Int(UInt8(ascii: ":"))].insert(.hasColon)
        table[Int(UInt8(ascii: "+"))].insert(.hasSign)
        table[Int(UInt8(ascii: "-"))].insert(.hasSign)

        return table
    }()

    private static func tryGetWeekday(_ token: DateToken, _ text: [UInt8], weekday: inout Int) -> Bool {
        if !token.isWeekday || token.length < 3 {
            return false
        }
        let name = String(bytes: text[token.start..<(token.start + 3)], encoding: .ascii) ?? ""
        if let index = weekDays.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            weekday = index
            return true
        }
        return false
    }

    private static func tryGetDayOfMonth(_ token: DateToken, _ text: [UInt8], day: inout Int) -> Bool {
        if !token.isNumeric {
            return false
        }
        let endIndex = token.start + token.length
        var index = token.start
        day = 0
        if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &day) {
            return false
        }
        return day > 0 && day <= 31
    }

    private static func tryGetMonth(_ token: DateToken, _ text: [UInt8], month: inout Int) -> Bool {
        if !token.isMonth || token.length < 3 {
            return false
        }
        let name = String(bytes: text[token.start..<(token.start + 3)], encoding: .ascii) ?? ""
        if let index = months.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            month = index + 1
            return true
        }
        return false
    }

    private static func tryGetYear(_ token: DateToken, _ text: [UInt8], year: inout Int) -> Bool {
        if !token.isNumeric {
            return false
        }
        let endIndex = token.start + token.length
        var index = token.start
        year = 0
        if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &year) {
            return false
        }
        if year < 100 {
            year += (year < 70) ? 2000 : 1900
        }
        return year >= 1969
    }

    private static func tryGetTimeOfDay(_ token: DateToken, _ text: [UInt8], hour: inout Int, minute: inout Int, second: inout Int) -> Bool {
        if !token.isTimeOfDay {
            return false
        }
        let endIndex = token.start + token.length
        var index = token.start
        hour = 0
        minute = 0
        second = 0

        if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &hour) || hour > 23 {
            return false
        }
        if index >= endIndex || text[index] != UInt8(ascii: ":") {
            return false
        }
        index += 1

        if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &minute) || minute > 59 {
            return false
        }
        if index >= endIndex || text[index] != UInt8(ascii: ":") {
            return true
        }
        index += 1

        if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &second) || second > 60 {
            return false
        }

        if hour == 23 && minute == 59 && second == 60 {
            second = 59
        } else if second == 60 {
            return false
        }

        return index == endIndex
    }

    private static func isAmOrPm(_ token: DateToken, _ text: [UInt8], hour: inout Int) -> Bool {
        if token.isAlphaZone && token.length == 2 {
            let second = text[token.start + 1]
            if second == UInt8(ascii: "M") || second == UInt8(ascii: "m") {
                let first = text[token.start]
                if first == UInt8(ascii: "A") || first == UInt8(ascii: "a") {
                    if hour == 12 {
                        hour = 0
                    }
                    return true
                }
                if first == UInt8(ascii: "P") || first == UInt8(ascii: "p") {
                    if hour < 12 {
                        hour += 12
                    }
                    return true
                }
            }
        }
        return false
    }

    private static func tryGetTimeZone(_ token: DateToken, _ text: [UInt8], tzone: inout Int) -> Bool {
        tzone = 0

        if token.isNumericZone {
            let endIndex = token.start + token.length
            var index = token.start
            let sign: Int
            if text[index] == UInt8(ascii: "-") {
                sign = -1
            } else if text[index] == UInt8(ascii: "+") {
                sign = 1
            } else {
                return false
            }
            index += 1
            if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &tzone) || index != endIndex {
                return false
            }
            tzone *= sign
        } else if token.isAlphaZone {
            if token.length > 3 {
                return false
            }
            let name = String(bytes: text[token.start..<(token.start + token.length)], encoding: .ascii) ?? ""
            guard let value = timezones[name] else {
                return false
            }
            tzone = value
        } else if token.isNumeric {
            let endIndex = token.start + token.length
            var index = token.start
            if !ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &tzone) || index != endIndex {
                return false
            }
        }

        return tzone >= -1200 && tzone <= 1400
    }

    private static func isTokenDelimiter(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: "-") || byte == UInt8(ascii: "/") || byte == UInt8(ascii: ",") || ByteClassification.isWhitespace(byte)
    }

    private static func tokenizeDate(_ text: [UInt8], startIndex: Int, length: Int) -> [DateToken] {
        var tokens: [DateToken] = []
        let endIndex = startIndex + length
        var index = startIndex

        while index < endIndex {
            if (try? ParseUtils.skipCommentsAndWhiteSpace(text, index: &index, endIndex: endIndex, throwOnError: false)) != true {
                break
            }
            if index >= endIndex {
                break
            }

            let mask = datetok[Int(text[index])]
            if mask != .none {
                let start = index
                var flags = mask
                index += 1
                while index < endIndex && !isTokenDelimiter(text[index]) {
                    flags.formUnion(datetok[Int(text[index])])
                    index += 1
                }
                tokens.append(DateToken(flags: flags, start: start, length: index - start))
            }

            index += 1
        }

        return tokens
    }

    private static func tryParseStandardDateFormat(_ tokens: [DateToken], _ text: [UInt8], date: inout DateTimeOffset?) -> Bool {
        date = nil
        var n = 0

        if tokens.count < 5 {
            return false
        }

        var weekday = 0
        if tryGetWeekday(tokens[n], text, weekday: &weekday) {
            if tokens.count < 6 {
                return false
            }
            n += 1
        }

        var day = 0
        if !tryGetDayOfMonth(tokens[n], text, day: &day) {
            return false
        }
        n += 1

        var month = 0
        if !tryGetMonth(tokens[n], text, month: &month) {
            return false
        }
        n += 1

        var year = 0
        if !tryGetYear(tokens[n], text, year: &year) {
            return false
        }
        n += 1

        var hour = 0
        var minute = 0
        var second = 0
        if !tryGetTimeOfDay(tokens[n], text, hour: &hour, minute: &minute, second: &second) {
            return false
        }
        n += 1

        if n < tokens.count, isAmOrPm(tokens[n], text, hour: &hour) {
            n += 1
        }

        var tzone = 0
        if n < tokens.count, !tryGetTimeZone(tokens[n], text, tzone: &tzone) {
            tzone = 0
        }

        let hours = tzone / 100
        let minutes = tzone % 100
        let offsetMinutes = (hours * 60) + minutes

        date = DateTimeOffset(year: year, month: month, day: day, hour: hour, minute: minute, second: second, offsetMinutes: offsetMinutes)
        return date != nil
    }

    private static func tryParseUnknownDateFormat(_ tokens: [DateToken], _ text: [UInt8], date: inout DateTimeOffset?) -> Bool {
        var day: Int? = nil
        var month: Int? = nil
        var year: Int? = nil
        var tzone: Int? = nil
        var hour = 0
        var minute = 0
        var second = 0
        var numericMonth = false
        var haveWeekday = false
        var haveTime = false
        var haveAmPm = false

        for token in tokens {
            if !haveWeekday {
                var weekday = 0
                if tryGetWeekday(token, text, weekday: &weekday) {
                    haveWeekday = true
                    continue
                }
            }

            if (month == nil || numericMonth) {
                var value = 0
                if tryGetMonth(token, text, month: &value) {
                    if numericMonth {
                        numericMonth = false
                        day = month
                    }
                    month = value
                    continue
                }
            }

            if !haveTime {
                var h = 0, m = 0, s = 0
                if tryGetTimeOfDay(token, text, hour: &h, minute: &m, second: &s) {
                    hour = h
                    minute = m
                    second = s
                    haveTime = true
                    continue
                }
            }

            if haveTime && tzone == nil && !haveAmPm {
                var h = hour
                if isAmOrPm(token, text, hour: &h) {
                    hour = h
                    haveAmPm = true
                    continue
                }
            }

            if tzone == nil && token.isTimeZone {
                var tz = 0
                if tryGetTimeZone(token, text, tzone: &tz) {
                    tzone = tz
                    continue
                }
            }

            if token.isNumeric {
                var value = 0
                if token.length == 4 {
                    if year == nil {
                        if tryGetYear(token, text, year: &value) {
                            year = value
                        }
                    } else if tzone == nil {
                        if tryGetTimeZone(token, text, tzone: &value) {
                            tzone = value
                        }
                    }
                    continue
                }

                if token.length > 2 {
                    continue
                }

                let endIndex = token.start + token.length
                var index = token.start
                _ = ParseUtils.tryParseInt32(text, index: &index, endIndex: endIndex, value: &value)

                if month == nil && value > 0 && value <= 12 {
                    numericMonth = true
                    month = value
                    continue
                }

                if day == nil && value > 0 && value <= 31 {
                    day = value
                    continue
                }

                if year == nil && value >= 69 {
                    year = 1900 + value
                    continue
                }
            }
        }

        guard let yearValue = year, let monthValue = month, let dayValue = day else {
            date = nil
            return false
        }

        if !haveTime {
            hour = 0
            minute = 0
            second = 0
        }

        let offsetMinutes: Int
        if let tzone {
            let hours = tzone / 100
            let minutes = tzone % 100
            offsetMinutes = (hours * 60) + minutes
        } else {
            offsetMinutes = 0
        }

        date = DateTimeOffset(year: yearValue, month: monthValue, day: dayValue, hour: hour, minute: minute, second: second, offsetMinutes: offsetMinutes)
        return date != nil
    }

    /// Tries to parse a date from a byte buffer.
    ///
    /// Parses an RFC 2822 date and time from the supplied buffer starting at the
    /// given index and spanning across the specified number of bytes. This method
    /// is tolerant of many non-standard date formats commonly found in email messages.
    ///
    /// - Parameters:
    ///   - buffer: The input byte buffer containing the date string.
    ///   - startIndex: The starting index of the input buffer.
    ///   - length: The number of bytes in the input buffer to parse.
    ///   - date: On successful return, contains the parsed date. On failure,
    ///     contains `nil`.
    /// - Returns: `true` if the date was successfully parsed; otherwise, `false`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let buffer = Array("Mon, 15 Mar 2024 14:30:00 -0500".utf8)
    /// var date: DateTimeOffset?
    /// if DateUtils.tryParse(buffer, startIndex: 0, length: buffer.count, date: &date) {
    ///     print(date!)
    /// }
    /// ```
    public static func tryParse(_ buffer: [UInt8]?, startIndex: Int, length: Int, date: inout DateTimeOffset?) -> Bool {
        guard let buffer else {
            date = nil
            return false
        }
        guard startIndex >= 0, length >= 0, startIndex + length <= buffer.count else {
            date = nil
            return false
        }

        let tokens = tokenizeDate(buffer, startIndex: startIndex, length: length)
        if tryParseStandardDateFormat(tokens, buffer, date: &date) {
            return true
        }
        if tryParseUnknownDateFormat(tokens, buffer, date: &date) {
            return true
        }

        date = nil
        return false
    }

    /// Tries to parse a date from a byte buffer starting at the specified index.
    ///
    /// Parses an RFC 2822 date and time from the supplied buffer starting at the
    /// specified index through the end of the buffer.
    ///
    /// - Parameters:
    ///   - buffer: The input byte buffer containing the date string.
    ///   - startIndex: The starting index of the input buffer.
    ///   - date: On successful return, contains the parsed date. On failure,
    ///     contains `nil`.
    /// - Returns: `true` if the date was successfully parsed; otherwise, `false`.
    public static func tryParse(_ buffer: [UInt8]?, startIndex: Int, date: inout DateTimeOffset?) -> Bool {
        guard let buffer else {
            date = nil
            return false
        }
        return tryParse(buffer, startIndex: startIndex, length: buffer.count - startIndex, date: &date)
    }

    /// Tries to parse a date from a byte buffer.
    ///
    /// Parses an RFC 2822 date and time from the entire buffer.
    ///
    /// - Parameters:
    ///   - buffer: The input byte buffer containing the date string.
    ///   - date: On successful return, contains the parsed date. On failure,
    ///     contains `nil`.
    /// - Returns: `true` if the date was successfully parsed; otherwise, `false`.
    public static func tryParse(_ buffer: [UInt8]?, date: inout DateTimeOffset?) -> Bool {
        guard let buffer else {
            date = nil
            return false
        }
        return tryParse(buffer, startIndex: 0, length: buffer.count, date: &date)
    }

    /// Tries to parse a date from a string.
    ///
    /// Parses an RFC 2822 date and time from the specified text. This is the
    /// most convenient method for parsing date strings.
    ///
    /// - Parameters:
    ///   - text: The input text containing the date string.
    ///   - date: On successful return, contains the parsed date. On failure,
    ///     contains `nil`.
    /// - Returns: `true` if the date was successfully parsed; otherwise, `false`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var date: DateTimeOffset?
    /// if DateUtils.tryParse("Mon, 15 Mar 2024 14:30:00 -0500", date: &date) {
    ///     print(date!)
    /// }
    /// ```
    public static func tryParse(_ text: String?, date: inout DateTimeOffset?) -> Bool {
        guard let text else {
            date = nil
            return false
        }
        let buffer = Array(text.utf8)
        return tryParse(buffer, startIndex: 0, length: buffer.count, date: &date)
    }

    /// Formats a date as an RFC 2822 date string.
    ///
    /// Formats the date and time in the format specified by RFC 2822, suitable
    /// for use in the Date header of MIME messages.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: The formatted date string.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let date = DateTimeOffset.now()
    /// let formatted = DateUtils.formatDate(date)
    /// // "Mon, 15 Mar 2024 14:30:00 -0500"
    /// ```
    ///
    /// ## Format
    ///
    /// The output format is: `Ddd, DD Mon YYYY HH:MM:SS +HHMM`
    /// - Ddd: Three-letter weekday abbreviation
    /// - DD: Two-digit day of month
    /// - Mon: Three-letter month abbreviation
    /// - YYYY: Four-digit year
    /// - HH:MM:SS: Time in 24-hour format
    /// - +HHMM: Timezone offset from UTC
    public static func formatDate(_ date: DateTimeOffset) -> String {
        let weekday = weekDays[date.dayOfWeek]
        let day = String(format: "%02d", date.day)
        let month = months[max(0, date.month - 1)]
        let year = String(format: "%04d", date.year)
        let hour = String(format: "%02d", date.hour)
        let minute = String(format: "%02d", date.minute)
        let second = String(format: "%02d", date.second)

        let offset = date.offsetMinutes
        let sign = offset < 0 ? "-" : "+"
        let absOffset = abs(offset)
        let tzHours = absOffset / 60
        let tzMinutes = absOffset % 60
        let tz = String(format: "%@%02d%02d", sign, tzHours, tzMinutes)

        return "\(weekday), \(day) \(month) \(year) \(hour):\(minute):\(second) \(tz)"
    }
}
