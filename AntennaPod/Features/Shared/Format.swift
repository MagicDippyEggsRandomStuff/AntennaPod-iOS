import Foundation

enum Format {
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static func shortDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return shortDateFormatter.string(from: date)
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "never" }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func speedLabel(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let text = formatter.string(from: NSNumber(value: value)) ?? String(value)
        return text + "×"
    }

    static func minutes(_ seconds: Int) -> String {
        if seconds % 60 == 0 {
            return "\(seconds / 60) min"
        }
        return "\(seconds) s"
    }
}
