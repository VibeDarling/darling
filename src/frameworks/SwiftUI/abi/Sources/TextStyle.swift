import CoreFoundation

private struct FontKey: EnvironmentKey { static let defaultValue: Font? = nil }
private struct TextStyleKey: EnvironmentKey { static let defaultValue = TextStyleDefaults() }
struct TextStyleDefaults {
    var weight: Font.Weight?
    var design: Font.Design?
    var italic: Bool?
    var tracking: CGFloat?
    var kerning: CGFloat?
    var monospacedDigits: Bool?
}
extension EnvironmentValues {
    public var font: Font? { get { self[FontKey.self] } set { self[FontKey.self] = newValue } }
    var textStyle: TextStyleDefaults { get { self[TextStyleKey.self] } set { self[TextStyleKey.self] = newValue } }
}
struct ResolvedTextStyle {
    var font: Font
    var defaults: TextStyleDefaults
    init(_ inputs: _ViewInputs) { font = inputs.environment.font ?? .body; defaults = inputs.environment.textStyle }
    var properties: [String: String] {
        let descriptor = font.provider.value
        let weight = defaults.weight ?? descriptor.weight ?? descriptor.defaultWeight
        let design = defaults.design ?? descriptor.design ?? .default
        let designID: Int
        switch design { case .default: designID = 0; case .serif: designID = 1; case .rounded: designID = 2; case .monospaced: designID = 3 }
        return ["font-size": String(Double(descriptor.pointSize)), "font-weight": String(Double(weight.value)),
            "font-design": String(designID), "font-italic": String(defaults.italic ?? descriptor.italic),
            "letter-spacing": String(Double(defaults.tracking ?? defaults.kerning ?? 0)),
            "monospaced-digits": String(defaults.monospacedDigits ?? descriptor.monospacedDigits),
            "font-name": descriptor.name ?? ""]
    }
}
private enum TextStyleOperation: Equatable {
    case italic(Bool), design(Font.Design?), digits
    func apply(to style: inout ResolvedTextStyle) {
        switch self { case .italic(let value): style.defaults.italic = value; case .design(let value): style.defaults.design = value; case .digits: style.defaults.monospacedDigits = true }
    }
}
private final class TextStyleOverride: AnyTextModifier {
    let operation: TextStyleOperation
    init(_ operation: TextStyleOperation) { self.operation = operation }
    override func apply(style: inout ResolvedTextStyle, paint: inout ResolvedPaint, inputs: _ViewInputs) { operation.apply(to: &style) }
    override func isEqual(to other: AnyTextModifier) -> Bool { (other as? TextStyleOverride)?.operation == operation }
}

struct TextStyleEnvironmentModifier: ViewModifier {
    let update: (inout TextStyleDefaults) -> Void
    typealias Body = Never
    static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var inputs = inputs; modifier.value.update(&inputs.environment.textStyle)
        return body(_Graph(), inputs)
    }
}
extension View {
    @inlinable public func font(_ font: Font?) -> some View { environment(\.font, font) }
    public func fontWeight(_ weight: Font.Weight?) -> some View { modifier(TextStyleEnvironmentModifier { $0.weight = weight }) }
    public func fontDesign(_ design: Font.Design?) -> some View { modifier(TextStyleEnvironmentModifier { $0.design = design }) }
    public func italic(_ isActive: Bool = true) -> some View { modifier(TextStyleEnvironmentModifier { $0.italic = isActive }) }
    public func bold(_ isActive: Bool = true) -> some View { modifier(TextStyleEnvironmentModifier { $0.weight = isActive ? .bold : .regular }) }
    public func monospacedDigit() -> some View { modifier(TextStyleEnvironmentModifier { $0.monospacedDigits = true }) }
    public func monospaced(_ isActive: Bool = true) -> some View { modifier(TextStyleEnvironmentModifier { $0.design = isActive ? .monospaced : nil }) }
    public func tracking(_ tracking: CGFloat) -> some View {
        precondition(tracking.isFinite)
        return modifier(TextStyleEnvironmentModifier { $0.tracking = tracking })
    }
    public func kerning(_ kerning: CGFloat) -> some View {
        precondition(kerning.isFinite)
        return modifier(TextStyleEnvironmentModifier { $0.kerning = kerning })
    }
}
extension Text {
    public func font(_ font: Font?) -> Text { var result = self; result.modifiers.append(.font(font)); return result }
    public func fontWeight(_ weight: Font.Weight?) -> Text { var result = self; result.modifiers.append(.weight(weight)); return result }
    public func tracking(_ tracking: CGFloat) -> Text { precondition(tracking.isFinite); var result = self; result.modifiers.append(.tracking(tracking)); return result }
    public func kerning(_ kerning: CGFloat) -> Text { precondition(kerning.isFinite); var result = self; result.modifiers.append(.kerning(kerning)); return result }
    private func styleOverride(_ operation: TextStyleOperation) -> Text {
        var result = self; result.modifiers.append(.anyTextModifier(TextStyleOverride(operation))); return result
    }
    public func italic() -> Text { var result = self; result.modifiers.append(.italic); return result }
    public func italic(_ isActive: Bool) -> Text { isActive ? italic() : styleOverride(.italic(false)) }
    public func bold() -> Text { fontWeight(.bold) }
    public func bold(_ isActive: Bool) -> Text { fontWeight(isActive ? .bold : .regular) }
    public func fontDesign(_ design: Font.Design?) -> Text { styleOverride(.design(design)) }
    public func monospacedDigit() -> Text { styleOverride(.digits) }
    public func monospaced(_ isActive: Bool = true) -> Text { fontDesign(isActive ? .monospaced : nil) }
}
