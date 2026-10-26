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
// DateTimeOffset.swift
//
// Ported from MimeKit (C#) to Swift.
//

import Foundation

/// A date and time with a fixed UTC offset.
///
/// `DateTimeOffset` represents a specific point in time along with the timezone offset
/// that was used to express it. This is essential for email headers (RFC 2822) where
/// the original timezone offset must be preserved for proper formatting.
///
/// Unlike `Date`, which only represents a point in time, `DateTimeOffset` remembers
/// the timezone context in which the date was expressed.
///
/// ## Creating a DateTimeOffset
///
/// ```swift
/// // From components
/// let date = DateTimeOffset(year: 2024, month: 3, day: 15,
///                           hour: 14, minute: 30, second: 0,
///                           offsetMinutes: -300)  // EST (-05:00)
///
/// // From existing Date with offset
/// let now = DateTimeOffset(date: Date(), offsetMinutes: 0)  // UTC
///
/// // Current time in local timezone
/// let local = DateTimeOffset.now()
/// ```
///
/// ## Formatting for Email Headers
///
/// ```swift
/// let formatted = DateUtils.formatDate(date)
/// // "Fri, 15 Mar 2024 14:30:00 -0500"
/// ```
public struct DateTimeOffset: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    /// The point in time represented by this value.
    public let date: Date

    /// The UTC offset in minutes.
    ///
    /// Positive values are east of UTC, negative values are west.
    /// For example, EST (UTC-5) is represented as `-300`.
    public let offsetMinutes: Int

    /// Creates a `DateTimeOffset` from date components and a UTC offset.
    ///
    /// - Parameters:
    ///   - year: The year component.
    ///   - month: The month component (1-12).
    ///   - day: The day component (1-31).
    ///   - hour: The hour component (0-23).
    ///   - minute: The minute component (0-59).
    ///   - second: The second component (0-59).
    ///   - offsetMinutes: The UTC offset in minutes.
    /// - Returns: A new `DateTimeOffset`, or `nil` if the components are invalid.
    public init?(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, offsetMinutes: Int) {
        guard let timeZone = TimeZone(secondsFromGMT: offsetMinutes * 60) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        guard let date = calendar.date(from: components) else {
            return nil
        }
        self.date = date
        self.offsetMinutes = offsetMinutes
    }

    /// Creates a `DateTimeOffset` from an existing `Date` and UTC offset.
    ///
    /// - Parameters:
    ///   - date: The point in time.
    ///   - offsetMinutes: The UTC offset in minutes to use when formatting.
    public init(date: Date, offsetMinutes: Int) {
        self.date = date
        self.offsetMinutes = offsetMinutes
    }

    /// Returns the current date and time in the local timezone.
    public static func now() -> DateTimeOffset {
        let now = Date()
        let offset = TimeZone.current.secondsFromGMT(for: now) / 60
        return DateTimeOffset(date: now, offsetMinutes: offset)
    }

    /// Returns the current date and time in UTC.
    public static func utcNow() -> DateTimeOffset {
        DateTimeOffset(date: Date(), offsetMinutes: 0)
    }

    // MARK: - Date Components

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: offsetMinutes * 60) ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// The year component in the offset's timezone.
    public var year: Int {
        calendar.component(.year, from: date)
    }

    /// The month component (1-12) in the offset's timezone.
    public var month: Int {
        calendar.component(.month, from: date)
    }

    /// The day component (1-31) in the offset's timezone.
    public var day: Int {
        calendar.component(.day, from: date)
    }

    /// The hour component (0-23) in the offset's timezone.
    public var hour: Int {
        calendar.component(.hour, from: date)
    }

    /// The minute component (0-59) in the offset's timezone.
    public var minute: Int {
        calendar.component(.minute, from: date)
    }

    /// The second component (0-59) in the offset's timezone.
    public var second: Int {
        calendar.component(.second, from: date)
    }

    /// The day of week (0 = Sunday, 6 = Saturday) in the offset's timezone.
    public var dayOfWeek: Int {
        let weekday = calendar.component(.weekday, from: date)
        return max(0, weekday - 1)
    }

    /// The timezone represented by this offset.
    public var timeZone: TimeZone {
        TimeZone(secondsFromGMT: offsetMinutes * 60) ?? TimeZone(secondsFromGMT: 0)!
    }

    // MARK: - Conversion

    /// Returns a new `DateTimeOffset` representing the same point in time with a different offset.
    ///
    /// - Parameter offsetMinutes: The new UTC offset in minutes.
    /// - Returns: A new `DateTimeOffset` with the same `date` but different `offsetMinutes`.
    public func toOffset(_ offsetMinutes: Int) -> DateTimeOffset {
        DateTimeOffset(date: date, offsetMinutes: offsetMinutes)
    }

    /// Returns this date converted to UTC (offset of 0).
    public var utc: DateTimeOffset {
        toOffset(0)
    }

    // MARK: - Protocol Conformances

    /// RFC 2822 formatted string representation.
    public var description: String {
        DateUtils.formatDate(self)
    }

    /// Compares two `DateTimeOffset` values by their point in time.
    ///
    /// The comparison is based on the `date` property, ignoring the offset.
    /// Two values representing the same instant in different timezones are considered equal
    /// for ordering purposes.
    public static func < (lhs: DateTimeOffset, rhs: DateTimeOffset) -> Bool {
        lhs.date < rhs.date
    }
}
