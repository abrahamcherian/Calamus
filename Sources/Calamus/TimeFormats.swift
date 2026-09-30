import Foundation

/// One way of writing the current time, e.g. "2026-09-25 14:35:09".
struct TimeFormat {
    let id: String
    let label: String
    let isUTC: Bool
    let render: (Date) -> String

    func string(for date: Date) -> String { render(date) }
}

/// The date/time formats offered by the Insert menu.
enum TimeFormats {
    private static func fixed(_ pattern: String, utc: Bool) -> (Date) -> String {
        return { date in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = utc ? (TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!) : TimeZone.autoupdatingCurrent
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }
    }

    private static func styled(date: DateFormatter.Style, time: DateFormatter.Style) -> (Date) -> String {
        return { value in
            let formatter = DateFormatter()
            formatter.locale = Locale.autoupdatingCurrent
            formatter.timeZone = TimeZone.autoupdatingCurrent
            formatter.dateStyle = date
            formatter.timeStyle = time
            return formatter.string(from: value)
        }
    }

    static let local: [TimeFormat] = [
        TimeFormat(id: "local.time24", label: "24-hour time", isUTC: false, render: fixed("HH:mm:ss", utc: false)),
        TimeFormat(id: "local.time24short", label: "24-hour time, no seconds", isUTC: false, render: fixed("HH:mm", utc: false)),
        TimeFormat(id: "local.time12", label: "12-hour time", isUTC: false, render: fixed("h:mm:ss a", utc: false)),
        TimeFormat(id: "local.dateTime", label: "Date and time", isUTC: false, render: fixed("yyyy-MM-dd HH:mm:ss", utc: false)),
        TimeFormat(id: "local.dateTimeZone", label: "Date, time and time zone", isUTC: false, render: fixed("yyyy-MM-dd HH:mm:ss zzz", utc: false)),
        TimeFormat(id: "local.long", label: "Long date and time", isUTC: false, render: styled(date: .full, time: .short)),
        TimeFormat(id: "local.short", label: "Short date and time (system style)", isUTC: false, render: styled(date: .short, time: .short)),
        TimeFormat(id: "local.iso", label: "ISO 8601 with offset", isUTC: false, render: fixed("yyyy-MM-dd'T'HH:mm:ssxxx", utc: false)),
        TimeFormat(id: "local.rfc2822", label: "RFC 2822", isUTC: false, render: fixed("EEE, dd MMM yyyy HH:mm:ss Z", utc: false)),
        TimeFormat(id: "local.compact", label: "Compact (for file names)", isUTC: false, render: fixed("yyyyMMdd_HHmmss", utc: false))
    ]

    static let utc: [TimeFormat] = [
        TimeFormat(id: "utc.time", label: "UTC time", isUTC: true, render: fixed("HH:mm:ss 'UTC'", utc: true)),
        TimeFormat(id: "utc.dateTime", label: "UTC date and time", isUTC: true, render: fixed("yyyy-MM-dd HH:mm:ss 'UTC'", utc: true)),
        TimeFormat(id: "utc.iso", label: "ISO 8601 (UTC)", isUTC: true, render: fixed("yyyy-MM-dd'T'HH:mm:ss'Z'", utc: true)),
        TimeFormat(id: "utc.rfc2822", label: "RFC 2822 (UTC)", isUTC: true, render: fixed("EEE, dd MMM yyyy HH:mm:ss 'GMT'", utc: true)),
        TimeFormat(id: "utc.compact", label: "Compact UTC (for file names)", isUTC: true, render: fixed("yyyyMMdd'T'HHmmss'Z'", utc: true)),
        TimeFormat(id: "utc.unix", label: "Unix time (seconds)", isUTC: true, render: { String(Int($0.timeIntervalSince1970)) }),
        TimeFormat(id: "utc.unixms", label: "Unix time (milliseconds)", isUTC: true, render: { String(Int(($0.timeIntervalSince1970 * 1000).rounded())) })
    ]

    static let all: [TimeFormat] = local + utc

    /// True when the Mac's region uses a 12-hour clock (e.g. the US), false for 24-hour regions.
    static var localeUses12HourClock: Bool {
        let pattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.autoupdatingCurrent) ?? ""
        return pattern.contains("a")
    }

    /// Keyboard shortcuts (Option-Command-digit) for the most common formats. The plain-time shortcut
    /// follows your region: 12-hour time where that is normal, 24-hour time elsewhere.
    static func shortcutDigits() -> [String: String] {
        [
            localeUses12HourClock ? "local.time12" : "local.time24": "1",
            "local.short": "2",      // date and time in your region's own style
            "local.dateTime": "3",   // 2026-09-25 14:35:09
            "local.iso": "4",        // 2026-09-25T14:35:09-05:00
            "utc.dateTime": "5",     // 2026-09-25 19:35:09 UTC
            "utc.iso": "6"           // 2026-09-25T19:35:09Z
        ]
    }

    static func format(withID id: String) -> TimeFormat? {
        all.first { $0.id == id }
    }

    /// e.g. "CDT, UTC-05:00" for the section title.
    static func localZoneDescription(for date: Date = Date()) -> String {
        let zone = TimeZone.autoupdatingCurrent
        let seconds = zone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let offset = String(format: "UTC%@%02d:%02d", sign, hours, minutes)
        if let abbreviation = zone.abbreviation(for: date) { return "\(abbreviation), \(offset)" }
        return offset
    }
}
