import Foundation

public enum DurationParser {
    public static func seconds(from string: String?) -> TimeInterval? {
        guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let lowered = raw.lowercased()
        if lowered.contains("h") || lowered.contains("m") || lowered.contains("s") {
            if let value = parseUnits(lowered) { return value }
        }

        let parts = raw.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        switch parts.count {
        case 1:
            return Double(parts[0])
        case 2:
            guard let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return nil }
            return minutes * 60 + seconds
        case 3:
            guard let hours = Double(parts[0]), let minutes = Double(parts[1]), let seconds = Double(parts[2]) else {
                return nil
            }
            return hours * 3600 + minutes * 60 + seconds
        default:
            return nil
        }
    }

    private static func parseUnits(_ value: String) -> TimeInterval? {
        var total: TimeInterval = 0
        var number = ""
        var matched = false
        for character in value {
            if character.isNumber || character == "." || character == "," {
                number.append(character == "," ? "." : character)
            } else if character == "h" || character == "m" || character == "s" {
                guard let amount = Double(number) else { return nil }
                switch character {
                case "h": total += amount * 3600
                case "m": total += amount * 60
                default: total += amount
                }
                number = ""
                matched = true
            } else if character == " " {
                continue
            } else {
                return nil
            }
        }
        return matched && number.isEmpty ? total : (matched ? total : nil)
    }

    public static func formatted(_ interval: TimeInterval, includeHours: Bool? = nil) -> String {
        guard interval.isFinite, interval >= 0 else { return "--:--" }
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        let showHours = includeHours ?? (hours > 0)
        if showHours {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
