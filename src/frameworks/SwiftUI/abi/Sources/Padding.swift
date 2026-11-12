import CoreFoundation

@frozen public struct _PaddingLayout: ViewModifier, Animatable {
    public var edges: Edge.Set
    public var insets: EdgeInsets?
    @inlinable public init(edges: Edge.Set = .all, insets: EdgeInsets?) { self.edges = edges; self.insets = insets }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let value = modifier.value
        let insets = value.insets ?? EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        var node = RenderNode(kind: "padding", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("padding")) ?? "",
                              children: [body(_Graph(), inputs.child("padded")).renderedNode])
        node.properties["top"] = String(Double(value.edges.contains(.top) ? insets.top : 0))
        node.properties["leading"] = String(Double(value.edges.contains(.leading) ? insets.leading : 0))
        node.properties["bottom"] = String(Double(value.edges.contains(.bottom) ? insets.bottom : 0))
        node.properties["trailing"] = String(Double(value.edges.contains(.trailing) ? insets.trailing : 0))
        return _ViewOutputs(node: node)
    }
}
extension View {
    @inlinable public func padding(_ insets: EdgeInsets) -> some View { modifier(_PaddingLayout(insets: insets)) }
    @inlinable public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        modifier(_PaddingLayout(edges: edges, insets: length.map { EdgeInsets(top: $0, leading: $0, bottom: $0, trailing: $0) }))
    }
    @inlinable public func padding(_ length: CGFloat) -> some View { padding(.all, length) }
}
