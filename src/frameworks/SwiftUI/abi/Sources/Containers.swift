// Frozen container storage follows the SDK and the pinned OpenSwiftUI sources.
@frozen public struct Group<Content> {
    @usableFromInline var content: Content
    public typealias Body = Never
}
extension Group: View where Content: View {
    @inlinable public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        Content._makeView(view: _GraphValue(value: view.value.content), inputs: inputs)
    }
}
@frozen public struct _ConditionalContent<TrueContent, FalseContent> {
    @usableFromInline @frozen enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }
    @usableFromInline let storage: Storage
}
extension _ConditionalContent: View where TrueContent: View, FalseContent: View {
    public typealias Body = Never
    @usableFromInline init(storage: Storage) { self.storage = storage }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        switch view.value.storage {
        case .trueContent(let value): return TrueContent._makeView(view: _GraphValue(value: value), inputs: inputs.child("true"))
        case .falseContent(let value): return FalseContent._makeView(view: _GraphValue(value: value), inputs: inputs.child("false"))
        }
    }
}
extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        switch view.value {
        case .some(let value): return Wrapped._makeView(view: _GraphValue(value: value), inputs: inputs)
        case .none: return _ViewOutputs(text: "")
        }
    }
}
extension ViewBuilder {
    public static func buildIf<Content: View>(_ content: Content?) -> Content? { content }
    public static func buildEither<TrueContent: View, FalseContent: View>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .trueContent(first))
    }
    public static func buildEither<TrueContent: View, FalseContent: View>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(storage: .falseContent(second))
    }
}
