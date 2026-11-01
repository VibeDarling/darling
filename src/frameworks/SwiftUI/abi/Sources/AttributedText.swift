import Foundation

// Keep the frozen Text representation: richer values live behind its existing
// reference storage case, while Foundation owns the attributed value's layout.
@usableFromInline final class AttributedTextStorage: AnyTextStorage {
    let value: AttributedString
    init(_ value: AttributedString) { self.value = value }
    override func isEqual(to other: AnyTextStorage) -> Bool {
        guard let other = other as? AttributedTextStorage else { return false }
        return value == other.value
    }
    override func resolve() -> (String, [[String: Any]]) {
        let characters = value.characters
        var offset = 0
        var runs: [[String: Any]] = []
        for run in value.runs {
            let text = String(characters[run.range])
            let length = text.utf16.count
            var entry: [String: Any] = ["start": offset, "end": offset + length,
                "intent": run.inlinePresentationIntent?.rawValue ?? 0]
            if let link = run.link { entry["link"] = link.absoluteString }
            runs.append(entry)
            offset += length
        }
        return (String(characters), runs)
    }
}
extension Text {
    public init(_ attributedContent: AttributedString) { storage = .anyTextStorage(AttributedTextStorage(attributedContent)) }
}
