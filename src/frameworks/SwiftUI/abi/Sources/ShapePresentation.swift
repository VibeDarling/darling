import Foundation
import CoreFoundation

// Retained in the render tree, with methods invoked on the main thread only.
// Geometry is evaluated after layout proposes its final point dimensions.
@objc(IOSAndroidSwiftUIShape) final class RuntimeShape: NSObject {
    private let size: (ProposedViewSize) -> CGSize
    private let path: (CGRect) -> Path
    private let fill: FillStyle
    init<S: Shape>(_ shape: S, fill: FillStyle) { size = shape.sizeThatFits; path = shape.path; self.fill = fill; super.init() }
    @objc(sizeForWidth:height:) func sizeForWidth(_ width: Double, height: Double) -> NSDictionary {
        let size = size(ProposedViewSize(width: width < 0 ? nil : CGFloat(width), height: height < 0 ? nil : CGFloat(height)))
        return ["width": Double(size.width), "height": Double(size.height)]._bridgeToObjectiveC()
    }
    @objc(pathForWidth:height:) func pathForWidth(_ width: Double, height: Double) -> NSDictionary {
        let path = path(CGRect(x: 0, y: 0, width: width, height: height))
        let commands: [[Double]] = path.elements.map { element in
            switch element {
            case .move(let p): return [0, Double(p.x), Double(p.y)]
            case .line(let p): return [1, Double(p.x), Double(p.y)]
            case let .quadCurve(p, c): return [2, Double(c.x), Double(c.y), Double(p.x), Double(p.y)]
            case let .curve(p, c1, c2): return [3, Double(c1.x), Double(c1.y), Double(c2.x), Double(c2.y), Double(p.x), Double(p.y)]
            case .closeSubpath: return [4]
            }
        }
        return ["commands": commands, "even-odd": fill.isEOFilled, "antialiased": fill.isAntialiased]._bridgeToObjectiveC()
    }
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
