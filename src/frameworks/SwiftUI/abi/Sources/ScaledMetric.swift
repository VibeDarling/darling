extension Font {
    public enum TextStyle: CaseIterable, Hashable {
        case largeTitle, title, title2, title3, headline, subheadline
        case body, callout, footnote, caption, caption2
    }
}

// Like State, an uninstalled metric uses its initial value. Dynamic type scaling
// needs a view graph and remains covered by DynamicProperty's installation guard.
@propertyWrapper public struct ScaledMetric<Value: BinaryFloatingPoint>: DynamicProperty {
    private let value: Value
    private let textStyle: Font.TextStyle
    public init(wrappedValue: Value, relativeTo textStyle: Font.TextStyle) {
        value = wrappedValue
        self.textStyle = textStyle
    }
    public init(wrappedValue: Value) { self.init(wrappedValue: wrappedValue, relativeTo: .body) }
    public var wrappedValue: Value { value }
}
