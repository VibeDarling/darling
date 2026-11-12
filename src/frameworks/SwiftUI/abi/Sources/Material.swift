// Public values and entry points follow the SDK. The native compositor owns a
// local approximation of Apple's private material blur/tint profiles.
public struct Material: Sendable {
    let kind: Int
    private init(_ kind: Int) { self.kind = kind }
    public static let ultraThin = Self(0)
    public static let thin = Self(1)
    public static let regular = Self(2)
    public static let thick = Self(3)
    public static let ultraThick = Self(4)
    public static let bar = Self(5)
    static func value(for kind: Int) -> Self { [ultraThin, thin, regular, thick, ultraThick, bar][kind] }
}
struct ResolvedMaterial: Equatable {
    let kind: Int
    let dark, reduceTransparency, increasedContrast: Bool
    var encoded: String { "\(kind),\(dark ? 1 : 0),\(reduceTransparency ? 1 : 0),\(increasedContrast ? 1 : 0)" }
    var value: Material { .value(for: kind) }
}
extension Material: ShapeStyle {
    public static func _makeView<S: Shape>(view: _GraphValue<_ShapeView<S, Material>>, inputs: _ViewInputs) -> _ViewOutputs {
        _ShapeView<S, Material>._makeView(view: view, inputs: inputs)
    }
    public func _apply(to shape: inout _ShapeStyle_Shape) {
        shape.result = ResolvedPaint(material: ResolvedMaterial(kind: kind, dark: shape.colorScheme == .dark,
            reduceTransparency: shape.reduceTransparency, increasedContrast: shape.increasedContrast))
    }
    public static func _apply(to type: inout _ShapeStyle_ShapeType) { type.isSupported = true }
}
extension ShapeStyle where Self == Material {
    public static var regularMaterial: Material { .regular }
    public static var thinMaterial: Material { .thin }
    public static var thickMaterial: Material { .thick }
    public static var ultraThinMaterial: Material { .ultraThin }
    public static var ultraThickMaterial: Material { .ultraThick }
    public static var bar: Material { .bar }
}
private struct BackgroundMaterialKey: EnvironmentKey { static let defaultValue: Material? = nil }
private struct ReduceTransparencyKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    public var backgroundMaterial: Material? {
        get { self[BackgroundMaterialKey.self] }
        set { self[BackgroundMaterialKey.self] = newValue }
    }
    public var accessibilityReduceTransparency: Bool { self[ReduceTransparencyKey.self] }
    public var _accessibilityReduceTransparency: Bool {
        get { self[ReduceTransparencyKey.self] }
        set { self[ReduceTransparencyKey.self] = newValue }
    }
}
