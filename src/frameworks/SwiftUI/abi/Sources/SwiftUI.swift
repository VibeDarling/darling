// Initial SwiftUI binary-compatibility slice, compiled as module SwiftUI.
// Protocol declarations and basic Text storage are adapted from OpenSwiftUI
// ec9e58ec7155ba29507072d9c5031b770968384c (MIT; see LICENSE.OpenSwiftUI).
// The independent contract is the iOS 16.4 SDK's public Swift interface.
// This uses the runtime's UIKit presenter, not OpenSwiftUI's full graph engine.
import CoreFoundation
import UIKit
import DarlingCoreDataBridge

// These types are resilient in the SDK. Their private representation belongs
// to this library; clients compiled against the SDK access it through metadata.
public struct _GraphValue<Value>: Equatable {
    let value: Value
    public static func == (lhs: Self, rhs: Self) -> Bool {
        fatalError("SwiftUI ABI slice: graph identity comparison is unsupported")
    }
}
public struct _ViewInputs {
    var objects: [ObjectIdentifier: AnyObject] = [:]
    var environment = EnvironmentValues()
    var foreground: [ResolvedPaint] = []
    var stackAxis: String?
    var appleButtonStyle = 0
    var graph: ViewGraph?
    var path = ViewPath()
    func child(_ identity: AnyHashable) -> Self {
        var result = self; result.path = path.child(identity); return result
    }
}
public struct _ViewOutputs {
    var node: RenderNode
    var text: String { node.plainText }
    var accessibility: [String: String] = [:]
    init(text: String) { node = RenderNode(kind: text.isEmpty ? "empty" : "text", text: text) }
    init(node: RenderNode) { self.node = node }
    var renderedNode: RenderNode {
        var result = node
        result.properties.merge(accessibility) { _, outer in outer }
        return result
    }
}
public struct _ViewListInputs { var viewInputs = _ViewInputs() }
public struct _ViewListOutputs {
    var view: _ViewOutputs
    var text: String { view.text }
    init(text: String) { view = _ViewOutputs(text: text) }
    init(view: _ViewOutputs) { self.view = view }
}
public struct _ViewListCountInputs {}
public struct _SceneInputs { var graph: ViewGraph? }
public struct _SceneOutputs {
    let text: String
    var accessibility: [String: String] = [:]
    var node: RenderNode?
}
public struct _DynamicPropertyBuffer {}
public struct _GraphInputs { var environment = EnvironmentValues() }

public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
    static func _valuesEqual(_ lhs: Value, _ rhs: Value) -> Bool
}
extension EnvironmentKey {
    public static func _valuesEqual(_ lhs: Value, _ rhs: Value) -> Bool { false }
}
extension EnvironmentKey where Value: Equatable {
    public static func _valuesEqual(_ lhs: Value, _ rhs: Value) -> Bool { lhs == rhs }
}
public enum ScenePhase: Comparable, Hashable {
    case background, inactive, active
    private var order: Int {
        switch self { case .background: return 0; case .inactive: return 1; case .active: return 2 }
    }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.order < rhs.order }
}
private struct ScenePhaseKey: EnvironmentKey { static let defaultValue = ScenePhase.background }
private struct IsEnabledKey: EnvironmentKey { static let defaultValue = true }
public struct EnvironmentValues: CustomStringConvertible {
    private var values: [ObjectIdentifier: Any] = [:]
    public init() {}
    public subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value {
        get { values[ObjectIdentifier(key)].map { $0 as! Key.Value } ?? Key.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }
    public var scenePhase: ScenePhase {
        get { self[ScenePhaseKey.self] }
        set { self[ScenePhaseKey.self] = newValue }
    }
    public var isEnabled: Bool {
        get { self[IsEnabledKey.self] }
        set { self[IsEnabledKey.self] = newValue }
    }
    public var description: String { "EnvironmentValues(\(values.count) overrides)" }
}
@frozen @propertyWrapper public struct Environment<Value>: DynamicProperty {
    @usableFromInline @frozen enum Content {
        case keyPath(KeyPath<EnvironmentValues, Value>)
        case value(Value)
    }
    @usableFromInline var content: Content
    @inlinable public init(_ keyPath: KeyPath<EnvironmentValues, Value>) { content = .keyPath(keyPath) }
    @inlinable public var wrappedValue: Value {
        switch content {
        case .value(let value): return value
        case .keyPath(let keyPath): return EnvironmentValues()[keyPath: keyPath]
        }
    }
}

// Frozen wrapper fields follow the SDK/OpenSwiftUI declarations. These support
// their documented behavior outside an installed view graph; graph installation
// still fails explicitly in DynamicProperty._makeProperty below.
@usableFromInline @frozen struct PropertyList {
    @usableFromInline class Element {}
    @usableFromInline var elements: Element? = nil
    @usableFromInline init() {}
}
@frozen public struct Transaction {
    @usableFromInline var plist: PropertyList
    @inlinable public init() { plist = PropertyList() }
}
@usableFromInline class AnyLocationBase {}
@usableFromInline class AnyLocation<Value>: AnyLocationBase {
    let get: () -> Value
    let set: (Value, Transaction) -> Void
    init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) {
        self.get = get
        self.set = set
    }
}
@frozen @propertyWrapper @dynamicMemberLookup public struct Binding<Value> {
    public var transaction: Transaction
    @usableFromInline var location: AnyLocation<Value>
    @usableFromInline var _value: Value
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.init(get: get, set: { value, _ in set(value) })
    }
    public init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) {
        transaction = Transaction()
        _value = get()
        location = AnyLocation(get: get, set: set)
    }
    public static func constant(_ value: Value) -> Binding<Value> {
        Binding(get: { value }, set: { _ in })
    }
    public var wrappedValue: Value {
        get { location.get() }
        nonmutating set { location.set(newValue, transaction) }
    }
    public var projectedValue: Binding<Value> { self }
    public init(projectedValue: Binding<Value>) { self = projectedValue }
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        Binding<Subject>(get: { wrappedValue[keyPath: keyPath] }, set: { value in
            var copy = wrappedValue
            copy[keyPath: keyPath] = value
            wrappedValue = copy
        })
    }
}
@frozen @propertyWrapper public struct State<Value>: DynamicProperty {
    @usableFromInline var _value: Value
    @usableFromInline var _location: AnyLocation<Value>?
    public init(wrappedValue value: Value) { _value = value; _location = nil }
    @inlinable public init(initialValue value: Value) { _value = value; _location = nil }
    public var wrappedValue: Value {
        get { _location?.get() ?? _value }
        nonmutating set { _location?.set(newValue, Transaction()) }
    }
    public var projectedValue: Binding<Value> {
        guard let location = _location else { return .constant(_value) }
        return Binding(get: location.get, set: location.set)
    }
}
extension State where Value: ExpressibleByNilLiteral {
    @inlinable public init() { self.init(wrappedValue: nil) }
}
@frozen @propertyWrapper public struct LazyState<Value>: DynamicProperty {
    @usableFromInline enum Storage {
        case thunk(() -> Value)
        case value(Value)
        var value: Value {
            switch self { case .thunk(let thunk): return thunk(); case .value(let value): return value }
        }
    }
    @usableFromInline var _storage: Storage
    @usableFromInline var _location: AnyLocation<Value>?
    public init(wrappedValue thunk: @autoclosure @escaping () -> Value) {
        _storage = .thunk(thunk)
        _location = nil
    }
    public var wrappedValue: Value {
        get { _location?.get() ?? _storage.value }
        nonmutating set { _location?.set(newValue, Transaction()) }
    }
    public var projectedValue: Binding<Value> {
        guard let location = _location else { return .constant(_storage.value) }
        return Binding(get: location.get, set: location.set)
    }
}
extension LazyState where Value: ExpressibleByNilLiteral {
    @inlinable public init() { self.init(wrappedValue: nil) }
}

// Requirement order is part of the ABI. In particular, do not add a renderer
// requirement to App: SDK-compiled conformances have no witness slot for one.
public protocol View {
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs
    static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs
    static func _viewListCount(inputs: _ViewListCountInputs) -> Int?
    associatedtype Body: View
    @ViewBuilder var body: Body { get }
}
extension View {
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        if Body.self == Never.self { return _darlingUnsupportedView(Self.self, inputs) }
        return EnvironmentScope.withObjects(inputs.objects) {
            var value = view.value
            let inputs = inputs.child(ObjectIdentifier(Self.self))
            inputs.graph?.install(&value, at: inputs.path, environment: inputs.environment)
            return Body._makeView(view: _GraphValue(value: value.body), inputs: inputs.child("body"))
        }
    }
    public static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        _ViewListOutputs(view: _makeView(view: view, inputs: inputs.viewInputs))
    }
    public static func _viewListCount(inputs: _ViewListCountInputs) -> Int? { nil }
}
extension View where Body == Never {
    public var body: Never { fatalError("SwiftUI primitive body must not be evaluated") }
}
extension Never: View {
    public typealias Body = Never
    public var body: Never { self }
}

@resultBuilder public struct ViewBuilder {
    public static func buildExpression<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<Content: View>(_ content: Content) -> Content { content }
}

@frozen public struct EmptyView: View {
    public init() {}
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _ViewOutputs(text: "")
    }
    public static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        _ViewListOutputs(text: "")
    }
    public static func _viewListCount(inputs: _ViewListCountInputs) -> Int? { 0 }
}

@usableFromInline class AnyShapeStyleBox {
    func apply(to shape: inout _ShapeStyle_Shape) { fatalError("SwiftUI: unsupported erased shape style") }
}
@usableFromInline class AnyFontBox {
    let value: FontDescriptor
    init(_ value: FontDescriptor) { self.value = value }
}
@frozen public struct Font: Hashable {
    @usableFromInline var provider: AnyFontBox
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.provider.value == rhs.provider.value }
    public func hash(into hasher: inout Hasher) { hasher.combine(provider.value) }
    @frozen public struct Weight: Hashable { @usableFromInline var value: CGFloat }
}
@usableFromInline class AnyTextStorage {
    func resolve() -> (String, [[String: Any]]) { fatalError("SwiftUI: unsupported text storage") }
    func isEqual(to other: AnyTextStorage) -> Bool { self === other }
}
@usableFromInline class AnyTextModifier {
    func apply(style: inout ResolvedTextStyle, paint: inout ResolvedPaint, inputs: _ViewInputs) { paint = self.paint(inputs) }
    func isEqual(to other: AnyTextModifier) -> Bool { self === other }
    func paint(_ inputs: _ViewInputs) -> ResolvedPaint {
        fatalError("SwiftUI: this text modifier is unsupported")
    }
}

@frozen public struct Text: Equatable {
    @usableFromInline @frozen enum Storage: Equatable {
        case verbatim(String)
        case anyTextStorage(AnyTextStorage)
        @usableFromInline static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case let (.verbatim(a), .verbatim(b)): return a == b
            case let (.anyTextStorage(a), .anyTextStorage(b)): return a.isEqual(to: b)
            default: return false
            }
        }
    }
    @usableFromInline @frozen enum Modifier: Equatable {
        case color(Color?)
        case font(Font?)
        case italic
        case weight(Font.Weight?)
        case kerning(CGFloat)
        case tracking(CGFloat)
        case baseline(CGFloat)
        case rounded
        case anyTextModifier(AnyTextModifier)
        @usableFromInline static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case let (.color(a), .color(b)): return a == b
            case let (.font(a), .font(b)): return a == b
            case (.italic, .italic), (.rounded, .rounded): return true
            case let (.weight(a), .weight(b)): return a == b
            case let (.kerning(a), .kerning(b)), let (.tracking(a), .tracking(b)),
                 let (.baseline(a), .baseline(b)): return a == b
            case let (.anyTextModifier(a), .anyTextModifier(b)): return a.isEqual(to: b)
            default: return false
            }
        }
    }
    @usableFromInline var storage: Storage
    @usableFromInline var modifiers: [Modifier] = []
    @inlinable public init(verbatim content: String) { storage = .verbatim(content) }
    @_disfavoredOverload public init<S: StringProtocol>(_ content: S) { storage = .verbatim(String(content)) }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage == rhs.storage && lhs.modifiers == rhs.modifiers
    }
}
extension Text: View {
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        var text: String
        var runs: [[String: Any]]
        switch view.value.storage {
        case .verbatim(let value): text = value; runs = []
        case .anyTextStorage(let storage): (text, runs) = storage.resolve()
        }
        applyTextCase(inputs.environment.textCase, text: &text, runs: &runs)
        var paint = ForegroundStyle().resolve(inputs)
        var style = ResolvedTextStyle(inputs)
        for modifier in view.value.modifiers {
            switch modifier {
            case .color(let color): paint = color?.resolve(inputs) ?? ForegroundStyle().resolve(inputs)
            case .font(let font): style.font = font ?? inputs.environment.font ?? .body
            case .weight(let weight): style.defaults.weight = weight ?? inputs.environment.textStyle.weight
            case .italic: style.defaults.italic = true
            case .tracking(let value): style.defaults.tracking = value
            case .kerning(let value): style.defaults.kerning = value
            case .rounded: style.defaults.design = .rounded
            case .anyTextModifier(let modifier): modifier.apply(style: &style, paint: &paint, inputs: inputs)
            default: fatalError("SwiftUI: this text modifier is unsupported")
            }
        }
        var output = _ViewOutputs(text: text)
        output.node.textRuns = runs
        output.node.properties.merge(style.properties) { _, local in local }
        if let limit = inputs.environment.lineLimit { output.node.properties["max-lines"] = String(max(0, limit)) }
        output.node.properties["min-lines"] = String(inputs.environment.minimumLines)
        // Track Swift Character boundaries, not UTF-16 units or Unicode scalars.
        output.node.textClusters = text.indices.map { index in
            text.utf16.distance(from: text.utf16.startIndex, to: text.index(after: index))
        }
        if let tint = inputs.environment.tint { output.node.properties["link-tint"] = tint.resolve(inputs).solidEncoded }
        else if let tint = inputs.environment.tintColor { output.node.properties["link-tint"] = tint.resolve(inputs).solidEncoded }
        output.node.properties["foreground"] = paint.solidEncoded
        output.node.identity = inputs.graph?.nodeIdentity(at: inputs.path.child("text")) ?? ""
        return output
    }
}

public protocol Scene {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
    static func _makeScene(scene: _GraphValue<Self>, inputs: _SceneInputs) -> _SceneOutputs
}
extension Scene {
    public static func _makeScene(scene: _GraphValue<Self>, inputs: _SceneInputs) -> _SceneOutputs {
        Body._makeScene(scene: _GraphValue(value: scene.value.body), inputs: inputs)
    }
}
extension Never: Scene {}
@resultBuilder public struct SceneBuilder {
    public static func buildExpression<Content: Scene>(_ content: Content) -> Content { content }
    public static func buildBlock<Content: Scene>(_ content: Content) -> Content { content }
}
private struct PrimitiveScene: Scene {
    var body: Never { fatalError("SwiftUI primitive scene body must not be evaluated") }
}

public struct WindowGroup<Content: View>: Scene {
    private let content: () -> Content
    public init(@ViewBuilder content: () -> Content) {
        let value = content()
        self.content = { value }
    }
    public init(id: String?, title: Text?, lazyContent: @escaping () -> Content) {
        precondition(id == nil && title == nil, "SwiftUI: named windows and window titles require scene support")
        content = lazyContent
    }
    public var body: some Scene { PrimitiveScene() }
    public static func _makeScene(scene: _GraphValue<Self>, inputs: _SceneInputs) -> _SceneOutputs {
        var viewInputs = _ViewInputs(graph: inputs.graph)
        viewInputs.environment.scenePhase = inputs.graph?.phase ?? .background
        let output = Content._makeView(view: _GraphValue(value: scene.value.content()), inputs: viewInputs)
        return _SceneOutputs(text: output.text, accessibility: output.accessibility, node: output.renderedNode)
    }
}

public protocol App {
    associatedtype Body: Scene
    @SceneBuilder var body: Body { get }
    init()
}
private var applicationDelegate: NSObject?

extension App {
    public static func main() {
        DarlingSwiftUIEntry()
        installButtonHandler()
        var app = Self()
        DarlingSwiftUIPhase(0)
        let graph = ViewGraph()
        DarlingSwiftUIPhase(1)
        applicationGraph = graph
        graph.render = {
            DarlingSwiftUIPhase(4)
            graph.install(&app, at: ViewPath(components: ["app"]))
            DarlingSwiftUIPhase(5)
            return Body._makeScene(scene: _GraphValue(value: app.body), inputs: _SceneInputs(graph: graph))
        }
        // As in SwiftUI, the scene's body is first evaluated once the application has finished
        // launching, after the adapted delegate's didFinishLaunching (where apps configure SDKs).
        DarlingSwiftUIPhase(2)
        darlingRunUIKit(delegate: applicationDelegate, startTasks: startInstalledTasks) {
            DarlingSwiftUIPhase(3)
            sendRenderTree(graph.update())
        }
    }
}

public protocol DynamicProperty {
    static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer,
                                container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs)
    static var _propertyBehaviors: UInt32 { get }
    mutating func update()
}
extension DynamicProperty {
    public static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer,
                                       container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs) {
        fatalError("SwiftUI ABI slice: dynamic property graph installation is unsupported")
    }
    public static var _propertyBehaviors: UInt32 { 0 }
    public mutating func update() {}
}

@propertyWrapper public struct UIApplicationDelegateAdaptor<DelegateType>: DynamicProperty
where DelegateType: NSObject, DelegateType: UIApplicationDelegate {
    public init(_ delegateType: DelegateType.Type = DelegateType.self) {
        precondition(applicationDelegate == nil, "Only one UIApplicationDelegateAdaptor is supported")
        applicationDelegate = delegateType.init()
    }
    public var wrappedValue: DelegateType {
        guard let delegate = applicationDelegate as? DelegateType else {
            fatalError("UIApplicationDelegateAdaptor used before delegate initialization")
        }
        return delegate
    }
}
