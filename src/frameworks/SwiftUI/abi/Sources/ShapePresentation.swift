import Foundation
import CoreFoundation

// Retained in the render tree, with methods invoked on the main thread only.
// Geometry is evaluated after layout proposes its final point dimensions.
@objc(IOSAndroidSwiftUIShape) final class RuntimeShape: NSObject {
    private let size: (ProposedViewSize) -> CGSize
    private let path: (CGRect) -> Path
    private let fill: FillStyle
    /// Set where the shape's path is stroked rather than filled.
    let stroke: StrokeStyle?
    init<S: Shape>(_ shape: S, fill: FillStyle) {
        size = shape.sizeThatFits; path = shape.path; self.fill = fill
        stroke = (shape as? DarlingStrokedShape)?.style
        super.init()
    }
    private init(size: @escaping (ProposedViewSize) -> CGSize, path: @escaping (CGRect) -> Path, fill: FillStyle, stroke: StrokeStyle?) {
        self.size = size; self.path = path; self.fill = fill; self.stroke = stroke
        super.init()
    }
    /// The shape turned by radians (clockwise, y pointing down) about anchor, as rotationEffect
    /// draws it; its layout does not change.
    func rotated(by radians: Double, anchor: UnitPoint) -> RuntimeShape {
        let path = self.path
        return RuntimeShape(size: size, path: { rect in
            let x = rect.minX + rect.width * anchor.x, y = rect.minY + rect.height * anchor.y
            let c = CGFloat(cos(radians)), s = CGFloat(sin(radians))
            return path(rect).applying(CGAffineTransform(a: c, b: s, c: -s, d: c, tx: x - c * x + s * y, ty: y - s * x - c * y))
        }, fill: fill, stroke: stroke)
    }
    /// The size the shape takes when proposed these dimensions; a negative one is unspecified.
    func size(width: Double, height: Double) -> CGSize {
        size(ProposedViewSize(width: width < 0 ? nil : CGFloat(width), height: height < 0 ? nil : CGFloat(height)))
    }
    func path(width: Double, height: Double) -> Path { path(CGRect(x: 0, y: 0, width: width, height: height)) }
    var isEOFilled: Bool { fill.isEOFilled }
}
func makeShapeOutput<S: Shape, Style: ShapeStyle>(_ shape: S, style: Style, fill: FillStyle, inputs: _ViewInputs, paint: ResolvedPaint? = nil) -> _ViewOutputs {
    var node = RenderNode(kind: "shape", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("shape")) ?? "")
    node.shape = RuntimeShape(shape, fill: fill)
    node.properties = (paint ?? style.resolve(inputs)).properties
    return _ViewOutputs(node: node)
}
@frozen public struct BackgroundStyle: ShapeStyle {
    @inlinable public init() {}
    public func _apply(to shape: inout _ShapeStyle_Shape) { shape.result = shape.colorScheme == .dark ? ResolvedPaint() : ResolvedPaint(red: 1, green: 1, blue: 1) }
    public static func _apply(to type: inout _ShapeStyle_ShapeType) { type.isSupported = true }
}
extension ShapeStyle where Self == BackgroundStyle { public static var background: Self { .init() } }
@frozen public struct _BackgroundShapeModifier<Style: ShapeStyle, Bounds: Shape>: ViewModifier {
    public var style: Style
    public var shape: Bounds
    public var fillStyle: FillStyle
    @inlinable public init(style: Style, shape: Bounds, fillStyle: FillStyle) { self.style = style; self.shape = shape; self.fillStyle = fillStyle }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let paint = modifier.value.style.resolve(inputs)
        var childInputs = inputs.child("primary")
        childInputs.environment.backgroundMaterial = paint.material?.value
        let base = body(_Graph(), childInputs)
        let decoration = makeShapeOutput(modifier.value.shape, style: modifier.value.style, fill: modifier.value.fillStyle, inputs: inputs.child("decoration"), paint: paint)
        return layerOutput(base: base, decoration: decoration.renderedNode, alignment: .center, background: true, inputs: inputs)
    }
}
@frozen public struct _InsettableBackgroundShapeModifier<Style: ShapeStyle, Bounds: InsettableShape>: ViewModifier {
    public var style: Style
    public var shape: Bounds
    public var fillStyle: FillStyle
    @inlinable public init(style: Style, shape: Bounds, fillStyle: FillStyle) { self.style = style; self.shape = shape; self.fillStyle = fillStyle }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        let paint = modifier.value.style.resolve(inputs)
        var childInputs = inputs.child("primary")
        childInputs.environment.backgroundMaterial = paint.material?.value
        let base = body(_Graph(), childInputs)
        let decoration = makeShapeOutput(modifier.value.shape.inset(by: 0), style: modifier.value.style, fill: modifier.value.fillStyle, inputs: inputs.child("decoration"), paint: paint)
        return layerOutput(base: base, decoration: decoration.renderedNode, alignment: .center, background: true, inputs: inputs)
    }
}
extension View {
    @inlinable public func background<S: Shape>(in shape: S, fillStyle: FillStyle = .init()) -> some View {
        modifier(_BackgroundShapeModifier(style: BackgroundStyle(), shape: shape, fillStyle: fillStyle))
    }
    @inlinable public func background<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = .init()) -> some View {
        modifier(_BackgroundShapeModifier(style: style, shape: shape, fillStyle: fillStyle))
    }
    @inlinable public func background<S: InsettableShape>(in shape: S, fillStyle: FillStyle = .init()) -> some View {
        modifier(_InsettableBackgroundShapeModifier(style: BackgroundStyle(), shape: shape, fillStyle: fillStyle))
    }
    @inlinable public func background<S: ShapeStyle, T: InsettableShape>(_ style: S, in shape: T, fillStyle: FillStyle = .init()) -> some View {
        modifier(_InsettableBackgroundShapeModifier(style: style, shape: shape, fillStyle: fillStyle))
    }
}
