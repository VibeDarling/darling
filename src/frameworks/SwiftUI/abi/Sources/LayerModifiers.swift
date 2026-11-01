// Overlay/background sizes come from their primary content, unlike ZStack.
import CoreFoundation

@frozen public enum Edge: Int8, CaseIterable {
    case top, leading, bottom, trailing
    @frozen public struct Set: OptionSet {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public init(_ edge: Edge) { rawValue = 1 << edge.rawValue }
        public static let top = Self(.top)
        public static let leading = Self(.leading)
        public static let bottom = Self(.bottom)
        public static let trailing = Self(.trailing)
        public static let all: Self = [.top, .leading, .bottom, .trailing]
        public static let horizontal: Self = [.leading, .trailing]
        public static let vertical: Self = [.top, .bottom]
    }
}
func layerOutput(base: _ViewOutputs, decoration: RenderNode, alignment: Alignment,
                         background: Bool, inputs: _ViewInputs) -> _ViewOutputs {
    let kind = background ? "background" : "overlay"
    return _ViewOutputs(node: RenderNode(kind: kind,
        identity: inputs.graph?.nodeIdentity(at: inputs.path.child(kind)) ?? "",
        children: background ? [decoration, base.renderedNode] : [base.renderedNode, decoration],
        horizontal: Int(alignment.horizontal.key.bits), vertical: Int(alignment.vertical.key.bits)))
}
@frozen public struct _OverlayModifier<Overlay: View>: ViewModifier {
    public var overlay: Overlay
    public var alignment: Alignment
    @inlinable public init(overlay: Overlay, alignment: Alignment = .center) { self.overlay = overlay; self.alignment = alignment }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let base = body(_Graph(), inputs.child("primary"))
        let decoration = Overlay._makeView(view: _GraphValue(value: modifier.value.overlay), inputs: inputs.child("decoration"))
        return layerOutput(base: base, decoration: decoration.renderedNode, alignment: modifier.value.alignment, background: false, inputs: inputs)
    }
}
extension _OverlayModifier: Equatable where Overlay: Equatable {}
@frozen public struct _BackgroundModifier<Background: View>: ViewModifier {
    public var background: Background
    public var alignment: Alignment
    @inlinable public init(background: Background, alignment: Alignment = .center) { self.background = background; self.alignment = alignment }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let base = body(_Graph(), inputs.child("primary"))
        let decoration = Background._makeView(view: _GraphValue(value: modifier.value.background), inputs: inputs.child("decoration"))
        return layerOutput(base: base, decoration: decoration.renderedNode, alignment: modifier.value.alignment, background: true, inputs: inputs)
    }
}
extension _BackgroundModifier: Equatable where Background: Equatable {}
private func styleLayer(_ paint: ResolvedPaint, edges: Edge.Set, base: _ViewOutputs, background: Bool, inputs: _ViewInputs) -> _ViewOutputs {
    var node = RenderNode(kind: "color")
    node.identity = inputs.graph?.nodeIdentity(at: inputs.path.child("decoration")) ?? ""
    node.properties = paint.properties
    node.properties["ignores-safe-area"] = String(edges.rawValue)
    return layerOutput(base: base, decoration: node, alignment: .center, background: background, inputs: inputs)
}
@frozen public struct _OverlayStyleModifier<Style: ShapeStyle>: ViewModifier {
    public var style: Style
    public var ignoresSafeAreaEdges: Edge.Set
    @inlinable public init(style: Style, ignoresSafeAreaEdges: Edge.Set) { self.style = style; self.ignoresSafeAreaEdges = ignoresSafeAreaEdges }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        styleLayer(modifier.value.style.resolve(inputs), edges: modifier.value.ignoresSafeAreaEdges,
                   base: body(_Graph(), inputs.child("primary")), background: false, inputs: inputs)
    }
}
@frozen public struct _BackgroundStyleModifier<Style: ShapeStyle>: ViewModifier {
    public var style: Style
    public var ignoresSafeAreaEdges: Edge.Set
    @inlinable public init(style: Style, ignoresSafeAreaEdges: Edge.Set) { self.style = style; self.ignoresSafeAreaEdges = ignoresSafeAreaEdges }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let paint = modifier.value.style.resolve(inputs)
        var childInputs = inputs.child("primary")
        childInputs.environment.backgroundMaterial = paint.material?.value
        return styleLayer(paint, edges: modifier.value.ignoresSafeAreaEdges,
                   base: body(_Graph(), childInputs), background: true, inputs: inputs)
    }
}
extension View {
    @inlinable @_disfavoredOverload public func overlay<Overlay: View>(_ overlay: Overlay, alignment: Alignment = .center) -> some View {
        modifier(_OverlayModifier(overlay: overlay, alignment: alignment))
    }
    @inlinable public func overlay<Overlay: View>(alignment: Alignment = .center, @ViewBuilder content: () -> Overlay) -> some View {
        modifier(_OverlayModifier(overlay: content(), alignment: alignment))
    }
    @inlinable @_disfavoredOverload public func background<Background: View>(_ background: Background, alignment: Alignment = .center) -> some View {
        modifier(_BackgroundModifier(background: background, alignment: alignment))
    }
    @inlinable public func background<Background: View>(alignment: Alignment = .center, @ViewBuilder content: () -> Background) -> some View {
        modifier(_BackgroundModifier(background: content(), alignment: alignment))
    }
    @inlinable public func overlay<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View {
        modifier(_OverlayStyleModifier(style: style, ignoresSafeAreaEdges: edges))
    }
    @inlinable public func background<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View {
        modifier(_BackgroundStyleModifier(style: style, ignoresSafeAreaEdges: edges))
    }
}
