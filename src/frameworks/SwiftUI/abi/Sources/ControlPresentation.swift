import Foundation

/// The actions of the buttons last rendered, with the graph that rendered each.
private var buttonActions: [String: (graph: ObjectIdentifier?, action: () -> Void)] = [:]
func clearButtonActions(_ graph: ViewGraph) {
    buttonActions = buttonActions.filter { $0.value.graph != ObjectIdentifier(graph) }
}
func darlingActivateButton(_ identifier: UnsafePointer<CChar>) -> Bool {
    guard let entry = buttonActions[String(cString: identifier)] else { return false }
    entry.action()
    return true
}
func installButtonHandler() {}

func makeButton(label: _ViewOutputs, action: @escaping () -> Void, inputs: _ViewInputs, apple: Bool = false) -> _ViewOutputs {
    let identity = inputs.graph?.nodeIdentity(at: inputs.path.child("button")) ?? UUID().uuidString
    let objects = inputs.objects
    buttonActions[identity] = (inputs.graph.map(ObjectIdentifier.init), { EnvironmentScope.withObjects(objects) { action() } })
    var node = RenderNode(kind: "button", identity: identity, children: [label.renderedNode])
    node.properties["action"] = identity
    node.properties["enabled"] = inputs.environment.isEnabled ? "true" : "false"
    node.properties["label"] = label.text
    node.properties["button-kind"] = apple ? "apple" : "plain"
    node.properties["button-style"] = String(inputs.appleButtonStyle)
    return _ViewOutputs(node: node)
}

// Cross-framework rendering hooks used by the AuthenticationServices overlay.
public struct _RuntimeAppleButton: View {
    private let title: String
    private let action: () -> Void
    public init(title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        var labelInputs = inputs
        labelInputs.foreground = [inputs.appleButtonStyle == 0 ? ResolvedPaint(red: 1, green: 1, blue: 1) : ResolvedPaint()]
        let label = Text._makeView(view: _GraphValue(value: Text(verbatim: view.value.title)), inputs: labelInputs.child("label"))
        return makeButton(label: label, action: view.value.action, inputs: inputs, apple: true)
    }
}
public struct _RuntimeAppleButtonStyle: ViewModifier {
    private let value: Int
    public init(_ value: Int) { self.value = value }
    public typealias Body = Never
    public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var inputs = inputs; inputs.appleButtonStyle = modifier.value.value
        return body(_Graph(), inputs)
    }
}
