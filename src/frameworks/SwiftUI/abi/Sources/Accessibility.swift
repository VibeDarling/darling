// Resilient SDK accessibility attachment storage. The text presenter maps
// these annotations to the UILabel that represents the rendered root.
public struct AccessibilityAttachmentModifier: ViewModifier {
    private var properties: [String: String] = [:]
    public typealias Body = Never
    fileprivate init(_ name: String, _ value: String) { properties[name] = value }
    fileprivate func setting(_ name: String, _ value: String) -> Self {
        var result = self
        result.properties[name] = value
        return result
    }
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var output = body(_Graph(), inputs)
        output.accessibility.merge(modifier.value.properties) { _, outer in outer }
        return output
    }
}

private func accessibilityText(_ text: Text) -> String {
    Text._makeView(view: _GraphValue(value: text), inputs: _ViewInputs()).text
}

public struct AccessibilityChildBehavior: Hashable {
    fileprivate let value: UInt8
    public static let ignore = Self(value: 0)
    public static let contain = Self(value: 1)
    public static let combine = Self(value: 2)
}
private struct AccessibilityElementView<Content: View>: View {
    let content: Content
    let behavior: AccessibilityChildBehavior
    typealias Body = Never
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        var output = Content._makeView(view: _GraphValue(value: view.value.content), inputs: inputs)
        output.accessibility["element"] = view.value.behavior == .contain ? "false" : "true"
        output.accessibility["children"] = String(view.value.behavior.value)
        return output
    }
}
extension View {
    public func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View {
        AccessibilityElementView(content: self, behavior: children)
    }
}

extension View {
    public func accessibilityLabel(_ text: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        modifier(AccessibilityAttachmentModifier("label", accessibilityText(text)))
    }
    public func accessibilityLabel(_ key: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityLabel(Text(key))
    }
    @_disfavoredOverload public func accessibilityLabel<S: StringProtocol>(_ text: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityLabel(Text(verbatim: String(text)))
    }
    public func accessibilityValue(_ text: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        modifier(AccessibilityAttachmentModifier("value", accessibilityText(text)))
    }
    public func accessibilityValue(_ key: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityValue(Text(key))
    }
    @_disfavoredOverload public func accessibilityValue<S: StringProtocol>(_ text: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityValue(Text(verbatim: String(text)))
    }
    public func accessibilityHint(_ text: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        modifier(AccessibilityAttachmentModifier("hint", accessibilityText(text)))
    }
    public func accessibilityHint(_ key: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityHint(Text(key))
    }
    @_disfavoredOverload public func accessibilityHint<S: StringProtocol>(_ text: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        accessibilityHint(Text(verbatim: String(text)))
    }
    public func accessibilityIdentifier(_ identifier: String) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        modifier(AccessibilityAttachmentModifier("identifier", identifier))
    }
    public func accessibilityHidden(_ hidden: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        modifier(AccessibilityAttachmentModifier("hidden", hidden ? "true" : "false"))
    }
}

extension View {
    /// Traits are not reported here; the modifier keeps the SDK's type.
    public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
        modifier(AccessibilityAttachmentModifier("traits", ""))
    }
}
extension ModifiedContent where Modifier == AccessibilityAttachmentModifier {
    public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Content, Modifier> { self }
    public func accessibilityLabel(_ text: Text) -> ModifiedContent<Content, Modifier> {
        ModifiedContent(content: content, modifier: modifier.setting("label", accessibilityText(text)))
    }
    public func accessibilityLabel(_ key: LocalizedStringKey) -> ModifiedContent<Content, Modifier> {
        accessibilityLabel(Text(key))
    }
    @_disfavoredOverload public func accessibilityLabel<S: StringProtocol>(_ text: S) -> ModifiedContent<Content, Modifier> {
        accessibilityLabel(Text(verbatim: String(text)))
    }
    public func accessibilityValue(_ text: Text) -> ModifiedContent<Content, Modifier> {
        ModifiedContent(content: content, modifier: modifier.setting("value", accessibilityText(text)))
    }
    public func accessibilityValue(_ key: LocalizedStringKey) -> ModifiedContent<Content, Modifier> {
        accessibilityValue(Text(key))
    }
    @_disfavoredOverload public func accessibilityValue<S: StringProtocol>(_ text: S) -> ModifiedContent<Content, Modifier> {
        accessibilityValue(Text(verbatim: String(text)))
    }
    public func accessibilityHint(_ text: Text) -> ModifiedContent<Content, Modifier> {
        ModifiedContent(content: content, modifier: modifier.setting("hint", accessibilityText(text)))
    }
    public func accessibilityHint(_ key: LocalizedStringKey) -> ModifiedContent<Content, Modifier> {
        accessibilityHint(Text(key))
    }
    @_disfavoredOverload public func accessibilityHint<S: StringProtocol>(_ text: S) -> ModifiedContent<Content, Modifier> {
        accessibilityHint(Text(verbatim: String(text)))
    }
    public func accessibilityIdentifier(_ identifier: String) -> ModifiedContent<Content, Modifier> {
        ModifiedContent(content: content, modifier: modifier.setting("identifier", identifier))
    }
    public func accessibilityHidden(_ hidden: Bool) -> ModifiedContent<Content, Modifier> {
        ModifiedContent(content: content, modifier: modifier.setting("hidden", hidden ? "true" : "false"))
    }
}
