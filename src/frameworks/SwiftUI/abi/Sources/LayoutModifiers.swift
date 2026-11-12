import CoreFoundation

@frozen public enum ContentMode: Hashable, CaseIterable { case fit, fill }

@frozen public struct _AspectRatioLayout: ViewModifier {
    public var aspectRatio: CGFloat?
    public var contentMode: ContentMode
    @inlinable public init(aspectRatio: CGFloat? = nil, contentMode: ContentMode) {
        self.aspectRatio = aspectRatio; self.contentMode = contentMode
    }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let value = modifier.value
        var node = RenderNode(kind: "aspect", children: [body(_Graph(), inputs).renderedNode])
        node.identity = inputs.graph?.nodeIdentity(at: inputs.path.child("aspect")) ?? ""
        if let ratio = value.aspectRatio { node.properties["ratio"] = String(Double(ratio)) }
        node.properties["mode"] = value.contentMode == .fit ? "fit" : "fill"
        return _ViewOutputs(node: node)
    }
}
@frozen public struct _FrameLayout: ViewModifier {
    @usableFromInline let width: CGFloat?
    @usableFromInline let height: CGFloat?
    @usableFromInline let alignment: Alignment
    @usableFromInline init(width: CGFloat?, height: CGFloat?, alignment: Alignment) {
        self.width = width; self.height = height; self.alignment = alignment
    }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let value = modifier.value
        var node = RenderNode(kind: "frame", children: [body(_Graph(), inputs).renderedNode],
            horizontal: Int(value.alignment.horizontal.key.bits), vertical: Int(value.alignment.vertical.key.bits))
        node.identity = inputs.graph?.nodeIdentity(at: inputs.path.child("frame")) ?? ""
        if let width = value.width { node.properties["width"] = String(Double(width)) }
        if let height = value.height { node.properties["height"] = String(Double(height)) }
        return _ViewOutputs(node: node)
    }
}
extension View {
    @inlinable public func aspectRatio(_ aspectRatio: CGFloat? = nil, contentMode: ContentMode) -> some View {
        modifier(_AspectRatioLayout(aspectRatio: aspectRatio, contentMode: contentMode))
    }
    @inlinable public func aspectRatio(_ aspectRatio: CGSize, contentMode: ContentMode) -> some View {
        self.aspectRatio(aspectRatio.width / aspectRatio.height, contentMode: contentMode)
    }
    @inlinable public func scaledToFit() -> some View { aspectRatio(contentMode: .fit) }
    @inlinable public func scaledToFill() -> some View { aspectRatio(contentMode: .fill) }
    @inlinable public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        modifier(_FrameLayout(width: width, height: height, alignment: alignment))
    }
}

@frozen public struct _FixedSizeLayout: ViewModifier, Animatable {
    @usableFromInline var horizontal: Bool
    @usableFromInline var vertical: Bool
    @inlinable public init(horizontal: Bool = true, vertical: Bool = true) {
        self.horizontal = horizontal; self.vertical = vertical
    }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var node = RenderNode(kind: "fixed-size", children: [body(_Graph(), inputs).renderedNode])
        node.identity = inputs.graph?.nodeIdentity(at: inputs.path.child("fixed-size")) ?? ""
        node.properties["fix-width"] = modifier.value.horizontal ? "true" : "false"
        node.properties["fix-height"] = modifier.value.vertical ? "true" : "false"
        return _ViewOutputs(node: node)
    }
}
extension View {
    @inlinable public func fixedSize(horizontal: Bool, vertical: Bool) -> some View {
        modifier(_FixedSizeLayout(horizontal: horizontal, vertical: vertical))
    }
    @inlinable public func fixedSize() -> some View { fixedSize(horizontal: true, vertical: true) }
}

@frozen public struct _FlexFrameLayout: ViewModifier, Animatable {
    @usableFromInline let minWidth: CGFloat?
    @usableFromInline let idealWidth: CGFloat?
    @usableFromInline let maxWidth: CGFloat?
    @usableFromInline let minHeight: CGFloat?
    @usableFromInline let idealHeight: CGFloat?
    @usableFromInline let maxHeight: CGFloat?
    @usableFromInline let alignment: Alignment
    @usableFromInline init(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                          minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment) {
        let lowW = minWidth.map { max(0, $0) }, lowH = minHeight.map { max(0, $0) }
        let idealW = idealWidth.map { max(lowW ?? 0, $0) }, idealH = idealHeight.map { max(lowH ?? 0, $0) }
        self.minWidth = lowW; self.minHeight = lowH
        self.idealWidth = idealW; self.idealHeight = idealH
        self.maxWidth = maxWidth.map { max(idealW ?? lowW ?? 0, $0) }
        self.maxHeight = maxHeight.map { max(idealH ?? lowH ?? 0, $0) }
        self.alignment = alignment
    }
    public typealias AnimatableData = EmptyAnimatableData
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let value = modifier.value
        var node = RenderNode(kind: "flex-frame", children: [body(_Graph(), inputs.child("framed")).renderedNode],
            horizontal: Int(value.alignment.horizontal.key.bits), vertical: Int(value.alignment.vertical.key.bits))
        node.identity = inputs.graph?.nodeIdentity(at: inputs.path.child("flex-frame")) ?? ""
        for (key, number) in [("min-width", value.minWidth), ("ideal-width", value.idealWidth), ("max-width", value.maxWidth),
                              ("min-height", value.minHeight), ("ideal-height", value.idealHeight), ("max-height", value.maxHeight)] {
            if let number = number { node.properties[key] = String(Double(number)) }
        }
        return _ViewOutputs(node: node)
    }
}
extension View {
    @inlinable public func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                                minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil,
                                alignment: Alignment = .center) -> some View {
        modifier(_FlexFrameLayout(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth,
                                  minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight, alignment: alignment))
    }
}
