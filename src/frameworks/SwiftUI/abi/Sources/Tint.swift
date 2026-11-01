// The SDK's inlined Color tint modifier forms a key path to this internal
// property, including its property descriptor. It must be a real declaration.
private struct TintColorKey: EnvironmentKey { static let defaultValue: Color? = nil }
extension EnvironmentValues {
    @usableFromInline var tintColor: Color? {
        get { self[TintColorKey.self] }
        set { self[TintColorKey.self] = newValue; self[TintKey.self] = nil }
    }
}
extension View {
    @inlinable @_disfavoredOverload public func tint(_ tint: Color?) -> some View {
        environment(\.tintColor, tint)
    }
}
private struct TintKey: EnvironmentKey { static let defaultValue: AnyShapeStyle? = nil }
extension EnvironmentValues {
    @usableFromInline var tint: AnyShapeStyle? {
        get { self[TintKey.self] }
        set { self[TintKey.self] = newValue; self[TintColorKey.self] = nil }
    }
}
extension View {
    @inlinable public func tint<S: ShapeStyle>(_ tint: S?) -> some View {
        environment(\.tint, tint.map(AnyShapeStyle.init))
    }
}
