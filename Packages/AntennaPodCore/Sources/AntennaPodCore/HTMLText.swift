import Foundation

public enum HTMLText {
    private static let blockTags = [
        "p", "div", "br", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6",
        "blockquote", "section", "article", "ul", "ol", "table"
    ]

    public static func plainText(from html: String?) -> String? {
        guard let html, !html.isEmpty else { return nil }
        var text = html

        for tag in blockTags {
            text = text.replacingOccurrences(
                of: "<\\s*/?\\s*\(tag)\\b[^>]*>",
                with: "\n",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        text = text.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        text = decodeEntities(in: text)
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        text = text.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    public static func decodeEntities(in input: String) -> String {
        var text = input
        let named: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&mdash;": "\u{2014}",
            "&ndash;": "\u{2013}",
            "&hellip;": "\u{2026}",
            "&rsquo;": "\u{2019}",
            "&lsquo;": "\u{2018}",
            "&ldquo;": "\u{201C}",
            "&rdquo;": "\u{201D}"
        ]
        for (entity, replacement) in named {
            text = text.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }

        let pattern = "&#(x?[0-9a-fA-F]+);"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: text),
                  let valueRange = Range(match.range(at: 1), in: text) else { continue }
            let raw = String(text[valueRange])
            let scalarValue: UInt32?
            if raw.lowercased().hasPrefix("x") {
                scalarValue = UInt32(raw.dropFirst(), radix: 16)
            } else {
                scalarValue = UInt32(raw)
            }
            if let scalarValue, let scalar = Unicode.Scalar(scalarValue) {
                text.replaceSubrange(fullRange, with: String(Character(scalar)))
            }
        }
        return text
    }
}

public extension String {
    var strippingHTML: String {
        HTMLText.plainText(from: self) ?? ""
    }
}
