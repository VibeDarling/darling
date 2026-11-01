import CoreFoundation

// Three SDK witness slots, without newer ShapeStyle.resolve requirements.
public protocol ShapeStyle {
    static func _makeView<S: Shape>(view: _GraphValue<_ShapeView<S, Self>>, inputs: _ViewInputs) -> _ViewOutputs
    func _apply(to shape: inout _ShapeStyle_Shape)
    static func _apply(to type: inout _ShapeStyle_ShapeType)
}
struct ResolvedPaint: Equatable {
    var red: Double = 0, green: Double = 0, blue: Double = 0, opacity: Double = 1
    var material: ResolvedMaterial?
    var properties: [String: String] {
        var result = ["foreground": encoded]
        if let material = material { result["material"] = material.encoded }
        return result
    }
    var solidEncoded: String {
        precondition(material == nil, "SwiftUI: material foreground text/image masks are not implemented")
        return encoded
    }
    var encoded: String { "\(red),\(green),\(blue),\(opacity)" }
    func multipliedOpacity(_ factor: Double) -> Self { var result = self; result.opacity *= factor; return result }
}
public struct _ShapeStyle_Shape {
    var foreground: [ResolvedPaint]
    var result: ResolvedPaint?
    var colorScheme: ColorScheme
    var reduceTransparency: Bool
    var increasedContrast: Bool
    var defaultPaint: ResolvedPaint { colorScheme == .dark ? ResolvedPaint(red: 1, green: 1, blue: 1) : ResolvedPaint() }
    init(_ inputs: _ViewInputs) {
        foreground = inputs.foreground; colorScheme = inputs.environment.colorScheme
        reduceTransparency = inputs.environment.accessibilityReduceTransparency
        increasedContrast = inputs.environment.colorSchemeContrast == .increased
    }
}
public struct _ShapeStyle_ShapeType { var isSupported = false }
extension ShapeStyle {
    public static func _makeView<S: Shape>(view: _GraphValue<_ShapeView<S, Self>>, inputs: _ViewInputs) -> _ViewOutputs {
        _ShapeView<S, Self>._makeView(view: view, inputs: inputs)
    }
    public func _apply(to shape: inout _ShapeStyle_Shape) {
        fatalError("SwiftUI: this shape style has no implemented color resolver")
    }
    public static func _apply(to type: inout _ShapeStyle_ShapeType) { type.isSupported = false }
    func resolve(_ inputs: _ViewInputs) -> ResolvedPaint {
        var shape = _ShapeStyle_Shape(inputs)
        _apply(to: &shape)
        guard let result = shape.result else { fatalError("SwiftUI: shape style did not produce a paint") }
        return result
    }
}
@frozen public struct ForegroundStyle: ShapeStyle {
    @inlinable public init() {}
    public func _apply(to shape: inout _ShapeStyle_Shape) { shape.result = shape.foreground.first ?? shape.defaultPaint }
    public static func _apply(to type: inout _ShapeStyle_ShapeType) { type.isSupported = true }
}
@frozen public struct HierarchicalShapeStyle: ShapeStyle {
    @usableFromInline var id: UInt32
    public static let primary = Self(id: 0)
    public static let secondary = Self(id: 1)
    public static let tertiary = Self(id: 2)
    public static let quaternary = Self(id: 3)
    public func _apply(to shape: inout _ShapeStyle_Shape) {
        let index = Int(id)
        if index < shape.foreground.count { shape.result = shape.foreground[index] }
        else {
            let opacity = [1.0, 0.6, 0.3, 0.18][min(index, 3)]
            shape.result = (shape.foreground.first ?? shape.defaultPaint).multipliedOpacity(opacity)
        }
    }
    public static func _apply(to type: inout _ShapeStyle_ShapeType) { type.isSupported = true }
}
extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var primary: Self { .primary }
    public static var secondary: Self { .secondary }
    public static var tertiary: Self { .tertiary }
    public static var quaternary: Self { .quaternary }
}
extension ShapeStyle where Self == ForegroundStyle { public static var foreground: Self { .init() } }

@frozen public struct _ForegroundStyleModifier<Style: ShapeStyle>: ViewModifier {
    public var style: Style
    @inlinable public init(style: Style) { self.style = style }
    public typealias Body = Never
    public static func _makeViewInputs(modifier: _GraphValue<Self>, inputs: inout _ViewInputs) {
        inputs.foreground = [modifier.value.style.resolve(inputs)]
    }
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var inputs = inputs; _makeViewInputs(modifier: modifier, inputs: &inputs)
        return body(_Graph(), inputs)
    }
}
@frozen public struct _ForegroundStyleModifier2<S1: ShapeStyle, S2: ShapeStyle>: ViewModifier {
    public var primary: S1
    public var secondary: S2
    @inlinable public init(primary: S1, secondary: S2) { self.primary = primary; self.secondary = secondary }
    public typealias Body = Never
    public static func _makeViewInputs(modifier: _GraphValue<Self>, inputs: inout _ViewInputs) {
        inputs.foreground = [modifier.value.primary.resolve(inputs), modifier.value.secondary.resolve(inputs)]
    }
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var inputs = inputs; _makeViewInputs(modifier: modifier, inputs: &inputs)
        return body(_Graph(), inputs)
    }
}
@frozen public struct _ForegroundStyleModifier3<S1: ShapeStyle, S2: ShapeStyle, S3: ShapeStyle>: ViewModifier {
    public var primary: S1
    public var secondary: S2
    public var tertiary: S3
    @inlinable public init(primary: S1, secondary: S2, tertiary: S3) { self.primary = primary; self.secondary = secondary; self.tertiary = tertiary }
    public typealias Body = Never
    public static func _makeViewInputs(modifier: _GraphValue<Self>, inputs: inout _ViewInputs) {
        inputs.foreground = [modifier.value.primary.resolve(inputs), modifier.value.secondary.resolve(inputs), modifier.value.tertiary.resolve(inputs)]
    }
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var inputs = inputs; _makeViewInputs(modifier: modifier, inputs: &inputs)
        return body(_Graph(), inputs)
    }
}
extension View {
    @inlinable public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View { modifier(_ForegroundStyleModifier(style: style)) }
    @inlinable public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle>(_ primary: S1, _ secondary: S2) -> some View {
        modifier(_ForegroundStyleModifier2(primary: primary, secondary: secondary))
    }
    @inlinable public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle, S3: ShapeStyle>(_ primary: S1, _ secondary: S2, _ tertiary: S3) -> some View {
        modifier(_ForegroundStyleModifier3(primary: primary, secondary: secondary, tertiary: tertiary))
    }
}
