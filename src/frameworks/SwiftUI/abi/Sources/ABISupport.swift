// Support for ABIGenerated.swift: the trap that stands in for an API body not written yet, and the
// equality helper for the resilient value types it declares.

import Darwin
/// Stops with the name of the SwiftUI API an app reached that Darling's SwiftUI does not implement.
@usableFromInline func _abiUnimplemented(_ api: String, file: StaticString = #fileID, line: UInt = #line) -> Never {
    fatalError("SwiftUI: \(api) is not implemented", file: file, line: line)
}

/// The tag distinguishing values of a resilient struct generated from the SDK interface.
func _abiTagOf<T>(_ value: T) -> Int {
    Mirror(reflecting: value).children.first { $0.label == "_abiTag" }?.value as? Int ?? 0
}

/// What a View modifier Darling does not implement yet returns: the content, unchanged. The first
/// use of each is logged, so an app's missing behaviour can be traced to the modifier.
var reportedModifiers = Set<String>()
func _darlingIgnoredModifier<Content: View>(_ content: Content, _ name: String) -> some View {
    if reportedModifiers.insert(name).inserted {
        fputs("SwiftUI: View.\(name) is not implemented; the view is shown without it\n", stderr)
    }
    return content
}

/// A primitive view Darling cannot draw yet: nothing is shown in its place, and the first one of
/// each type is logged.
private var reportedViews = Set<String>()
func _darlingUnsupportedView<V>(_ type: V.Type, _ inputs: _ViewInputs) -> _ViewOutputs {
    let name = String(describing: type)
    if reportedViews.insert(name).inserted { fputs("SwiftUI: \(name) is not implemented; nothing is drawn for it\n", stderr) }
    return _ViewOutputs(node: RenderNode(kind: "empty"))
}

/// A primitive modifier Darling does not apply yet: its content is shown unmodified.
func _darlingPassthrough<M>(_ type: M.Type, _ inputs: _ViewInputs, _ body: (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
    let name = String(describing: type)
    if reportedModifiers.insert(name).inserted { fputs("SwiftUI: \(name) is not applied; its content is shown unmodified\n", stderr) }
    return body(_Graph(), inputs)
}

/// What an initializer of a value type Darling does not implement yet makes: an inert value, which
/// the views and modifiers taking it ignore. The first one of each type is logged.
private var reportedValues = Set<String>()
func _abiInertValue(_ name: String) {
    if reportedValues.insert(name).inserted { fputs("SwiftUI: \(name) is not implemented; an inert value stands in\n", stderr) }
}
