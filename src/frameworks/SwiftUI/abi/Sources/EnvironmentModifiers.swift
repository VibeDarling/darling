import DarlingCoreDataBridge
// Frozen modifier storage and the single graph-input witness follow the SDK.
public protocol _GraphInputsModifier {
    static func _makeInputs(modifier: _GraphValue<Self>, inputs: inout _GraphInputs)
}
@frozen public struct _EnvironmentKeyWritingModifier<Value>: ViewModifier, _GraphInputsModifier {
    public var keyPath: WritableKeyPath<EnvironmentValues, Value>
    public var value: Value
    @inlinable public init(keyPath: WritableKeyPath<EnvironmentValues, Value>, value: Value) {
        self.keyPath = keyPath; self.value = value
    }
    public typealias Body = Never
    public static func _makeInputs(modifier: _GraphValue<Self>, inputs: inout _GraphInputs) {
        DarlingSwiftUIPhase(23)
        inputs.environment[keyPath: modifier.value.keyPath] = modifier.value.value
        DarlingSwiftUIPhase(24)
    }
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var inputs = inputs
        DarlingSwiftUIPhase(23)
        inputs.environment[keyPath: modifier.value.keyPath] = modifier.value.value
        DarlingSwiftUIPhase(24)
        return body(_Graph(), inputs)
    }
}
@frozen public struct _EnvironmentKeyTransformModifier<Value>: ViewModifier, _GraphInputsModifier {
    public var keyPath: WritableKeyPath<EnvironmentValues, Value>
    public var transform: (inout Value) -> Void
    @inlinable public init(keyPath: WritableKeyPath<EnvironmentValues, Value>, transform: @escaping (inout Value) -> Void) {
        self.keyPath = keyPath; self.transform = transform
    }
    public typealias Body = Never
    public static func _makeInputs(modifier: _GraphValue<Self>, inputs: inout _GraphInputs) {
        modifier.value.transform(&inputs.environment[keyPath: modifier.value.keyPath])
    }
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var inputs = inputs
        modifier.value.transform(&inputs.environment[keyPath: modifier.value.keyPath])
        return body(_Graph(), inputs)
    }
}
extension View {
    @inlinable public func environment<Value>(_ keyPath: WritableKeyPath<EnvironmentValues, Value>, _ value: Value) -> some View {
        modifier(_EnvironmentKeyWritingModifier(keyPath: keyPath, value: value))
    }
    @inlinable public func transformEnvironment<Value>(_ keyPath: WritableKeyPath<EnvironmentValues, Value>, transform: @escaping (inout Value) -> Void) -> some View {
        modifier(_EnvironmentKeyTransformModifier(keyPath: keyPath, transform: transform))
    }
    @inlinable public func disabled(_ disabled: Bool) -> some View {
        modifier(_EnvironmentKeyTransformModifier(keyPath: \.isEnabled, transform: { $0 = $0 && !disabled }))
    }
}
