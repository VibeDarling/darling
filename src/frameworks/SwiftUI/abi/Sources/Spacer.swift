import CoreFoundation

// A spacer grows on its containing stack's primary axis.
@frozen public struct Spacer: View {
    public var minLength: CGFloat?
    @inlinable public init(minLength: CGFloat? = nil) { self.minLength = minLength }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        var node = RenderNode(kind: "spacer", spacing: Double(view.value.minLength ?? 8))
        node.identity = inputs.graph?.nodeIdentity(at: inputs.path.child("spacer")) ?? ""
        node.properties["axis"] = inputs.stackAxis ?? "both"
        return _ViewOutputs(node: node)
    }
}
