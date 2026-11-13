import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public struct XMLNode: Equatable, Sendable {
    public var name: String
    public var attributes: [String: String]
    public var children: [XMLNode]
    public var text: String

    public init(name: String, attributes: [String: String] = [:], children: [XMLNode] = [], text: String = "") {
        self.name = name
        self.attributes = attributes
        self.children = children
        self.text = text
    }

    public var localName: String {
        guard let colon = name.firstIndex(of: ":") else { return name }
        return String(name[name.index(after: colon)...])
    }

    public var namespacePrefix: String? {
        guard let colon = name.firstIndex(of: ":") else { return nil }
        return String(name[..<colon]).lowercased()
    }

    public var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func children(named name: String) -> [XMLNode] {
        let lowered = name.lowercased()
        return children.filter {
            $0.name.lowercased() == lowered || $0.localName.lowercased() == lowered
        }
    }

    public func firstChild(named name: String) -> XMLNode? {
        let lowered = name.lowercased()
        return children.first {
            $0.name.lowercased() == lowered || $0.localName.lowercased() == lowered
        }
    }

    public func childText(_ name: String) -> String? {
        guard let node = firstChild(named: name) else { return nil }
        let value = node.trimmedText
        return value.isEmpty ? nil : value
    }

    public func attribute(_ names: String...) -> String? {
        let lowered = attributes.reduce(into: [String: String]()) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }
        for name in names {
            if let value = lowered[name.lowercased()], !value.isEmpty {
                return value
            }
        }
        return nil
    }

    public func attributeValue(_ name: String) -> String? {
        guard let colon = name.firstIndex(of: ":") else {
            return attribute(name)
        }
        let prefix = String(name[..<colon]).lowercased()
        let local = String(name[name.index(after: colon)...]).lowercased()
        for (key, value) in attributes {
            let loweredKey = key.lowercased()
            if loweredKey == local || loweredKey == "\(prefix):\(local)" {
                return value
            }
        }
        return nil
    }

    public var descendantTexts: [String] {
        var result: [String] = []
        let own = trimmedText
        if !own.isEmpty { result.append(own) }
        for child in children {
            result.append(contentsOf: child.descendantTexts)
        }
        return result
    }
}

public enum XMLTreeError: Error, LocalizedError {
    case parseFailed(String)
    case empty

    public var errorDescription: String? {
        switch self {
        case .parseFailed(let message): return "Could not parse XML: \(message)"
        case .empty: return "The document is empty"
        }
    }
}

public enum XMLTree {
    public static func parse(data: Data) throws -> XMLNode {
        let builder = XMLTreeBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), let root = builder.root else {
            if let error = builder.error ?? parser.parserError {
                throw XMLTreeError.parseFailed(error.localizedDescription)
            }
            throw XMLTreeError.empty
        }
        return root
    }

    public static func parse(string: String) throws -> XMLNode {
        guard let data = string.data(using: .utf8) else { throw XMLTreeError.empty }
        return try parse(data: data)
    }
}

private final class MutableNode {
    var name: String
    var attributes: [String: String]
    var children: [MutableNode] = []
    var text: String = ""

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    func snapshot() -> XMLNode {
        XMLNode(name: name,
                attributes: attributes,
                children: children.map { $0.snapshot() },
                text: text)
    }
}

private final class XMLTreeBuilder: NSObject, XMLParserDelegate {
    var root: XMLNode?
    var error: Error?
    private var rootNode: MutableNode?
    private var stack: [MutableNode] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        let node = MutableNode(name: elementName, attributes: attributeDict)
        if let parent = stack.last {
            parent.children.append(node)
        } else if rootNode == nil {
            rootNode = node
        }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard !stack.isEmpty else { return }
        stack.removeLast()
        if stack.isEmpty {
            root = rootNode?.snapshot()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let value = String(data: CDATABlock, encoding: .utf8) else { return }
        stack.last?.text += value
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = parseError
    }
}
