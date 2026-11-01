// onAppear/onDisappear and onChange(of:perform:). As in SwiftUI, the actions do not run while
// the view graph is evaluated: the graph queues them and runs them on the main run loop after
// the update, so state they change schedules another update.

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _AppearanceActionModifier : ViewModifier {
  public var appear: (() -> Swift.Void)?
  public var disappear: (() -> Swift.Void)?
  @inlinable public init(appear: (() -> Swift.Void)? = nil, disappear: (() -> Swift.Void)? = nil) {
        self.appear = appear
        self.disappear = disappear
    }
  public static func _makeView(modifier: _GraphValue<_AppearanceActionModifier>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
    inputs.graph?.appearance(at: inputs.path, appear: modifier.value.appear, disappear: modifier.value.disappear)
    return body(_Graph(), inputs)
  }
  public static func _makeViewList(modifier: _GraphValue<_AppearanceActionModifier>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs {
    inputs.viewInputs.graph?.appearance(at: inputs.viewInputs.path, appear: modifier.value.appear, disappear: modifier.value.disappear)
    return body(_Graph(), inputs)
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension _AppearanceActionModifier : _SceneModifier {
  public static func _makeScene(modifier: _GraphValue<_AppearanceActionModifier>, inputs: _SceneInputs, body: @escaping (_Graph, _SceneInputs) -> _SceneOutputs) -> _SceneOutputs { _abiUnimplemented("_AppearanceActionModifier._makeScene") }
  public typealias Body = Swift.Never
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@frozen public struct _ValueActionModifier<Value> : ViewModifier where Value : Swift.Equatable {
  public typealias Body = Swift.Never
  public var value: Value
  public var action: (Value) -> Swift.Void
  @inlinable public init(value: Value, action: @escaping (Value) -> Swift.Void) {
        (self.value, self.action) = (value, action)
    }
  public static func _makeView(modifier: _GraphValue<_ValueActionModifier<Value>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
    inputs.graph?.valueChange(at: inputs.path, value: modifier.value.value, action: modifier.value.action)
    return body(_Graph(), inputs)
  }
  public static func _makeViewList(modifier: _GraphValue<_ValueActionModifier<Value>>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs {
    inputs.viewInputs.graph?.valueChange(at: inputs.viewInputs.path, value: modifier.value.value, action: modifier.value.action)
    return body(_Graph(), inputs)
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _ValueActionModifier : _SceneModifier {
  public static func _makeScene(modifier: _GraphValue<_ValueActionModifier<Value>>, inputs: _SceneInputs, body: @escaping (_Graph, _SceneInputs) -> _SceneOutputs) -> _SceneOutputs {
    body(_Graph(), inputs)
  }
}
