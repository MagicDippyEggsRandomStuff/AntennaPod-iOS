import Foundation

public enum FeedDate {
    public static func parse(_ input: String?) -> Date? {
        guard var value = input?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        if let iso = ISO8601DateFormatter().date(from: value) {
            return iso
        }

        value = value.replacingOccurrences(of: "/", with: "-")
        value = value.replacingOccurrences(of: "  ", with: " ")
        value = value.replacingOccurrences(of: "CEST", with: "+0200")
        value = value.replacingOccurrences(of: "CET", with: "+0100")
        value = value.replacingOccurrences(of: "Sept", with: "Sep")

        if value.hasSuffix("Z") {
            value = String(value.dropLast()) + "+0000"
        }

        for pattern in patterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = pattern
            formatter.isLenient = false
            if let date = formatter.date(from: value) {
                return date
            }
        }

        for pattern in patterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = pattern
            formatter.isLenient = true
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private static let patterns: [String] = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm Z",
        "EEE, dd MMM yyyy HH:mm:ss",
        "EEE, dd MMMM yyyy HH:mm:ss Z",
        "EEEE, dd MMM yyyy HH:mm:ss Z",
        "EEEE, d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss Z",
        "EEE MMM d HH:mm:ss yyyy",
        "EEE d MMM yyyy HH:mm:ss 'GMT'Z (z)",
        "dd MMM yy HH:mm:ss Z",
        "dd MMM yyyy HH:mm:ss Z",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-ddZ",
        "yyyy-MM-dd",
        "yyyyMMdd"
    ]
}
