// Tuple storage is frozen in the SDK. Open each child's actual View witness
// rather than assuming the tuple's fields have a common size or representation.
@frozen public struct TupleView<T>: View {
    public var value: T
    @inlinable public init(_ value: T) { self.value = value }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let tuple = Mirror(reflecting: view.value.value)
        precondition(tuple.displayStyle == .tuple, "TupleView requires a tuple")
        var children: [RenderNode] = []
        for (index, field) in tuple.children.enumerated() {
            guard let child = field.value as? any View else { preconditionFailure("TupleView child does not conform to View") }
            func render<Child: View>(_ value: Child) -> _ViewOutputs {
                Child._makeView(view: _GraphValue(value: value), inputs: inputs.child(index))
            }
            let output = _openExistential(child, do: render)
            children += output.renderedNode.list
        }
        return _ViewOutputs(node: RenderNode(kind: "group", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("tuple")) ?? "", children: children))
    }
}

extension ViewBuilder {
    public static func buildBlock<A: View, B: View>(_ a: A, _ b: B) -> TupleView<(A, B)> { TupleView((a, b)) }
    public static func buildBlock<A: View, B: View, C: View>(_ a: A, _ b: B, _ c: C) -> TupleView<(A, B, C)> { TupleView((a, b, c)) }
    public static func buildBlock<A: View, B: View, C: View, D: View>(_ a: A, _ b: B, _ c: C, _ d: D) -> TupleView<(A, B, C, D)> { TupleView((a, b, c, d)) }
    public static func buildBlock<A: View, B: View, C: View, D: View, E: View>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> TupleView<(A, B, C, D, E)> { TupleView((a, b, c, d, e)) }
    public static func buildBlock<A: View, B: View, C: View, D: View, E: View, F: View>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> TupleView<(A, B, C, D, E, F)> { TupleView((a, b, c, d, e, f)) }
    public static func buildBlock<A: View, B: View, C: View, D: View, E: View, F: View, G: View>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> TupleView<(A, B, C, D, E, F, G)> { TupleView((a, b, c, d, e, f, g)) }
    public static func buildBlock<A: View, B: View, C: View, D: View, E: View, F: View, G: View, H: View>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> TupleView<(A, B, C, D, E, F, G, H)> { TupleView((a, b, c, d, e, f, g, h)) }
    public static func buildBlock<A: View, B: View, C: View, D: View, E: View, F: View, G: View, H: View, I: View>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> TupleView<(A, B, C, D, E, F, G, H, I)> { TupleView((a, b, c, d, e, f, g, h, i)) }
    public static func buildBlock<A: View, B: View, C: View, D: View, E: View, F: View, G: View, H: View, I: View, J: View>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> TupleView<(A, B, C, D, E, F, G, H, I, J)> { TupleView((a, b, c, d, e, f, g, h, i, j)) }
}
