import _Concurrency

public struct _Graph {}

private var pendingTasks: [() -> Void] = []
private var installedTasks: [Task<Void, Never>] = []
private func installTask<Identity: Equatable>(priority: TaskPriority, identity: Identity, inputs: _ViewInputs,
                                             action: @escaping @Sendable () async -> Void) {
    let objects = inputs.objects
    if let graph = inputs.graph {
        graph.task(at: inputs.path, identity: identity) {
            Task(priority: priority) {
                await EnvironmentScope.$taskObjects.withValue(objects) { await action() }
            }
        }
        return
    }
    pendingTasks.append {
        installedTasks.append(Task(priority: priority) {
            await EnvironmentScope.$taskObjects.withValue(objects) { await action() }
        })
    }
}

// Called by the UIKit presenter after the window and launch delegate are ready.
@_cdecl("iosandroid_swiftui_start_tasks")
func startInstalledTasks() {
    applicationGraph?.launch()
    let tasks = pendingTasks
    pendingTasks.removeAll()
    for start in tasks { start() }
}

@frozen public struct _TaskValueModifier<Value: Equatable>: ViewModifier {
    public var action: @Sendable () async -> Void
    public var priority: TaskPriority
    public var value: Value
    @inlinable public init(value: Value, priority: TaskPriority,
                          action: @escaping @Sendable () async -> Void) {
        self.action = action
        self.priority = priority
        self.value = value
    }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
                                body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        installTask(priority: modifier.value.priority, identity: modifier.value.value, inputs: inputs, action: modifier.value.action)
        return body(_Graph(), inputs)
    }
}

// Keep the requirement order of the SDK protocol: SDK-defined modifiers supply
// these witness tables, including the associated Body and body(content:) method.
public protocol ViewModifier {
    static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
                         body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs
    static func _makeViewList(modifier: _GraphValue<Self>, inputs: _ViewListInputs,
                             body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs
    static func _viewListCount(inputs: _ViewListCountInputs,
                               body: (_ViewListCountInputs) -> Int?) -> Int?
    associatedtype Body: View
    @ViewBuilder func body(content: Content) -> Body
    typealias Content = _ViewModifier_Content<Self>
}

public struct _ViewModifier_Content<Modifier: ViewModifier>: View {
    let render: (_ViewInputs) -> _ViewOutputs
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        view.value.render(inputs)
    }
}

extension ViewModifier {
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
                                body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        if Body.self == Never.self { return _darlingPassthrough(Self.self, inputs, body) }
        return EnvironmentScope.withObjects(inputs.objects) {
            var value = modifier.value
            inputs.graph?.install(&value, at: inputs.path.child("modifier-properties").child(ObjectIdentifier(Self.self)), environment: inputs.environment)
            let content = Content(render: { body(_Graph(), $0) })
            return Body._makeView(view: _GraphValue(value: value.body(content: content)), inputs: inputs)
        }
    }
    public static func _makeViewList(modifier: _GraphValue<Self>, inputs: _ViewListInputs,
                                    body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs {
        let result = _makeView(modifier: modifier, inputs: inputs.viewInputs) { graph, viewInputs in
            body(graph, _ViewListInputs(viewInputs: viewInputs)).view
        }
        return _ViewListOutputs(view: result)
    }
    public static func _viewListCount(inputs: _ViewListCountInputs,
                                      body: (_ViewListCountInputs) -> Int?) -> Int? { nil }
}
extension ViewModifier where Body == Never {
    public func body(content: Content) -> Never {
        return fatalError("SwiftUI primitive modifier body must not be evaluated")
    }
}

@frozen public struct ModifiedContent<Content, Modifier> {
    public typealias Body = Never
    public var content: Content
    public var modifier: Modifier
    @inlinable public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }
}
extension ModifiedContent: Equatable where Content: Equatable, Modifier: Equatable {}
extension ModifiedContent: View where Content: View, Modifier: ViewModifier {
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        Modifier._makeView(modifier: _GraphValue(value: view.value.modifier), inputs: inputs.child("modifier")) { _, inputs in
            Content._makeView(view: _GraphValue(value: view.value.content), inputs: inputs.child("content"))
        }
    }
}
extension View {
    @inlinable public func modifier<T: ViewModifier>(_ modifier: T) -> ModifiedContent<Self, T> {
        ModifiedContent(content: self, modifier: modifier)
    }
    @inlinable public func task(priority: TaskPriority = .userInitiated,
                               @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View {
        modifier(_TaskModifier(priority: priority, action: action))
    }
    @inlinable public func task<T: Equatable>(id value: T, priority: TaskPriority = .userInitiated,
                                             @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View {
        modifier(_TaskValueModifier(value: value, priority: priority, action: action))
    }
}

@frozen public struct EmptyModifier: ViewModifier {
    public static let identity = EmptyModifier()
    @inlinable public init() {}
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
                                body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        body(_Graph(), inputs)
    }
}

// Frozen SDK storage. The graph owns task identity and cancels removed tasks.
@frozen public struct _TaskModifier: ViewModifier {
    public var action: @Sendable () async -> Void
    public var priority: TaskPriority
    @inlinable public init(priority: TaskPriority, action: @escaping @Sendable () async -> Void) {
        self.priority = priority
        self.action = action
    }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
                                body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        installTask(priority: modifier.value.priority, identity: UInt8(0), inputs: inputs, action: modifier.value.action)
        return body(_Graph(), inputs)
    }
}
