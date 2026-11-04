import DarlingCoreDataBridge
// This implementation leaves some environment values unconfigured until
// explicitly supplied. A generic computed-property key-path assignment reads its getter
// for writeback, so use registered direct setters for those framework APIs.
// Entries contain only API identity and setter code, never context instances.
struct EnvironmentValueWriter {
    let keyPath: AnyKeyPath
    let apply: (inout EnvironmentValues, Any) -> Void
    init<Value>(_ keyPath: WritableKeyPath<EnvironmentValues, Value>,
                setter: @escaping (inout EnvironmentValues, Value) -> Void) {
        self.keyPath = keyPath
        apply = { environment, value in
            guard let value = value as? Value else {
                preconditionFailure("Environment write does not match its registered value type")
            }
            setter(&environment, value)
        }
    }
}
private enum EnvironmentWriteRegistry {
    static let writers: [AnyKeyPath: EnvironmentValueWriter] = {
        let context = managedObjectContextEnvironmentWriter
        return [context.keyPath: context]
    }()
}
extension EnvironmentValues {
    mutating func write<Value>(_ value: Value, at keyPath: WritableKeyPath<Self, Value>) {
        if let writer = EnvironmentWriteRegistry.writers[keyPath] {
            writer.apply(&self, value)
        } else {
            self[keyPath: keyPath] = value
        }
    }
}

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
        inputs.environment.write(modifier.value.value, at: modifier.value.keyPath)
        DarlingSwiftUIPhase(24)
    }
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var inputs = inputs
        DarlingSwiftUIPhase(23)
        inputs.environment.write(modifier.value.value, at: modifier.value.keyPath)
        DarlingSwiftUIPhase(24)
        if modifier.value.keyPath as AnyKeyPath == \EnvironmentValues.foregroundColor as AnyKeyPath,
           let color = modifier.value.value as? Color? {
            inputs.foreground = color.map { [$0.resolve(inputs)] } ?? []
        }
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
