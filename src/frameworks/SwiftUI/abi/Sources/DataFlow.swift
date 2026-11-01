// The Combine-era data flow property wrappers, with the frozen layouts of the SDK interface:
// ObservedObject, StateObject, EnvironmentObject, AppStorage, FocusState, GestureState, Namespace.
// They are installed by ViewGraph like State: StateObject keeps its object at the view's position,
// and every observed object's objectWillChange schedules an update of the graph.
import Combine
import Foundation

@propertyWrapper @frozen public struct ObservedObject<ObjectType>: DynamicProperty where ObjectType: ObservableObject {
    @dynamicMemberLookup @frozen public struct Wrapper {
        internal let root: ObjectType
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            let root = self.root
            return Binding(get: { root[keyPath: keyPath] }, set: { root[keyPath: keyPath] = $0 })
        }
    }
    @usableFromInline internal var _seed: Int = 0
    public init(wrappedValue: ObjectType) { self.wrappedValue = wrappedValue }
    public var wrappedValue: ObjectType
    public var projectedValue: ObservedObject<ObjectType>.Wrapper { Wrapper(root: wrappedValue) }
}

extension ObservedObject: InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath) {
        graph.observe(wrappedValue, at: path)
    }
}

extension ViewGraph {
    /// Updates the graph whenever `object` announces a change.
    func observe<Object: ObservableObject>(_ object: Object, at path: ViewPath) {
        subscription(at: path.child("objectWillChange")) {
            AnyCancellable(object.objectWillChange.sink { [weak self] _ in self?.invalidate("objectWillChange of \(Object.self) at \(path)") })
        }
    }
}

@frozen @propertyWrapper public struct StateObject<ObjectType>: DynamicProperty where ObjectType: ObservableObject {
    @usableFromInline @frozen internal enum Storage {
        case initially(() -> ObjectType)
        case object(ObservedObject<ObjectType>)
    }
    @usableFromInline internal var storage: StateObject<ObjectType>.Storage
    @inlinable public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) {
        storage = .initially(thunk)
    }
    public var wrappedValue: ObjectType {
        switch storage {
        case .initially(let thunk): return thunk()
        case .object(let observed): return observed.wrappedValue
        }
    }
    public var projectedValue: ObservedObject<ObjectType>.Wrapper { ObservedObject(wrappedValue: wrappedValue).projectedValue }
    public static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer, container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs) {}
}

extension StateObject: InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath) {
        let current = storage
        let location = graph.location(at: path) { () -> ObjectType in
            switch current {
            case .initially(let thunk): return thunk()
            case .object(let observed): return observed.wrappedValue
            }
        }
        let object = location.get()
        storage = .object(ObservedObject(wrappedValue: object))
        graph.observe(object, at: path)
    }
}

/// Environment objects travel in EnvironmentValues, keyed by their type, as in SwiftUI:
/// `environmentObject(_:)` is inlined into apps as `environment(T.environmentStore, object)`.
struct EnvironmentObjectKey<Object: AnyObject>: Hashable {}
extension EnvironmentValues {
    subscript<Object: AnyObject>(_darlingObject key: EnvironmentObjectKey<Object>) -> Object? {
        get { self[EnvironmentObjectStorage<Object>.self] }
        set { self[EnvironmentObjectStorage<Object>.self] = newValue }
    }
}
private struct EnvironmentObjectStorage<Object: AnyObject>: EnvironmentKey {
    static var defaultValue: Object? { nil }
}
extension ObservableObject {
    @usableFromInline internal static var environmentStore: WritableKeyPath<EnvironmentValues, Self?> {
        \EnvironmentValues.[_darlingObject: EnvironmentObjectKey<Self>()]
    }
}

@frozen @propertyWrapper public struct EnvironmentObject<ObjectType>: DynamicProperty where ObjectType: ObservableObject {
    @dynamicMemberLookup @frozen public struct Wrapper {
        internal let root: ObjectType
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            let root = self.root
            return Binding(get: { root[keyPath: keyPath] }, set: { root[keyPath: keyPath] = $0 })
        }
    }
    @inlinable public var wrappedValue: ObjectType {
        guard let store = _store else { error() }
        return store
    }
    @inlinable internal var optionalWrappedValue: ObjectType? { _store }
    @usableFromInline internal var _store: ObjectType?
    @usableFromInline internal var _seed: Int = 0
    public var projectedValue: EnvironmentObject<ObjectType>.Wrapper { Wrapper(root: wrappedValue) }
    @usableFromInline internal func error() -> Never {
        fatalError("No ObservableObject of type \(ObjectType.self) found. A View.environmentObject(_:) for \(ObjectType.self) may be missing as an ancestor of this view.")
    }
    public init() {}
    public static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer, container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs) {}
}

extension EnvironmentObject: InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath) {
        let values = graph.currentEnvironment ?? EnvironmentValues()
        _store = values[keyPath: ObjectType.environmentStore]
        if let object = _store { graph.observe(object, at: path) }
    }
}

// MARK: - AppStorage

@usableFromInline internal class UserDefaultLocation<Value> {
    let key: String
    let store: UserDefaults
    let defaultValue: Value
    let read: (Any?) -> Value?
    let write: (Value) -> Any?
    init(key: String, store: UserDefaults?, defaultValue: Value, read: @escaping (Any?) -> Value?, write: @escaping (Value) -> Any?) {
        self.key = key
        self.store = store ?? .standard
        self.defaultValue = defaultValue
        self.read = read
        self.write = write
    }
    var value: Value {
        get { read(store.object(forKey: key)) ?? defaultValue }
        set {
            if let object = write(newValue) { store.set(object, forKey: key) } else { store.removeObject(forKey: key) }
            applicationGraph?.invalidate("AppStorage \(key)")
        }
    }
}

@frozen @propertyWrapper public struct AppStorage<Value>: DynamicProperty {
    @usableFromInline internal var location: UserDefaultLocation<Value>
    init(_ key: String, store: UserDefaults?, defaultValue: Value, read: @escaping (Any?) -> Value?, write: @escaping (Value) -> Any?) {
        location = UserDefaultLocation(key: key, store: store, defaultValue: defaultValue, read: read, write: write)
    }
    public var wrappedValue: Value {
        get { location.value }
        nonmutating set { location.value = newValue }
    }
    public var projectedValue: Binding<Value> {
        let location = self.location
        return Binding(get: { location.value }, set: { location.value = $0 })
    }
    public static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer, container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs) {}
}

extension AppStorage {
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Bool {
        self.init(key, store: store, defaultValue: wrappedValue, read: { ($0 as? NSNumber)?.boolValue }, write: { NSNumber(value: $0) })
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Int {
        self.init(key, store: store, defaultValue: wrappedValue, read: { ($0 as? NSNumber)?.intValue }, write: { NSNumber(value: $0) })
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Double {
        self.init(key, store: store, defaultValue: wrappedValue, read: { ($0 as? NSNumber)?.doubleValue }, write: { NSNumber(value: $0) })
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == String {
        self.init(key, store: store, defaultValue: wrappedValue, read: { $0 as? String }, write: { $0 })
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == URL {
        self.init(key, store: store, defaultValue: wrappedValue, read: { ($0 as? String).flatMap(URL.init(string:)) }, write: { $0.absoluteString })
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Data {
        self.init(key, store: store, defaultValue: wrappedValue, read: { $0 as? Data }, write: { $0 })
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == Int {
        self.init(key, store: store, defaultValue: wrappedValue, read: { ($0 as? NSNumber).flatMap { Value(rawValue: $0.intValue) } }, write: { NSNumber(value: $0.rawValue) })
    }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == String {
        self.init(key, store: store, defaultValue: wrappedValue, read: { ($0 as? String).flatMap(Value.init(rawValue:)) }, write: { $0.rawValue })
    }
}

extension AppStorage where Value: ExpressibleByNilLiteral {
    public init(_ key: String, store: UserDefaults? = nil) where Value == Bool? {
        self.init(key, store: store, defaultValue: nil, read: { ($0 as? NSNumber).map { $0.boolValue } }, write: { $0.map { NSNumber(value: $0) } })
    }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Int? {
        self.init(key, store: store, defaultValue: nil, read: { ($0 as? NSNumber).map { $0.intValue } }, write: { $0.map { NSNumber(value: $0) } })
    }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Double? {
        self.init(key, store: store, defaultValue: nil, read: { ($0 as? NSNumber).map { $0.doubleValue } }, write: { $0.map { NSNumber(value: $0) } })
    }
    public init(_ key: String, store: UserDefaults? = nil) where Value == String? {
        self.init(key, store: store, defaultValue: nil, read: { ($0 as? String).map { $0 } }, write: { $0 })
    }
    public init(_ key: String, store: UserDefaults? = nil) where Value == URL? {
        self.init(key, store: store, defaultValue: nil, read: { ($0 as? String).map { URL(string: $0) } }, write: { $0?.absoluteString })
    }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Data? {
        self.init(key, store: store, defaultValue: nil, read: { ($0 as? Data).map { $0 } }, write: { $0 })
    }
    public init<R>(_ key: String, store: UserDefaults? = nil) where Value == R?, R: RawRepresentable, R.RawValue == String {
        self.init(key, store: store, defaultValue: nil, read: { ($0 as? String).map { R(rawValue: $0) } }, write: { $0?.rawValue })
    }
    public init<R>(_ key: String, store: UserDefaults? = nil) where Value == R?, R: RawRepresentable, R.RawValue == Int {
        self.init(key, store: store, defaultValue: nil, read: { ($0 as? NSNumber).map { R(rawValue: $0.intValue) } }, write: { $0.map { NSNumber(value: $0.rawValue) } })
    }
}

// MARK: - FocusState

/// Focus is tracked as a value only: Darling's renderer does not move keyboard focus yet.
@frozen @propertyWrapper public struct FocusState<Value>: DynamicProperty where Value: Hashable {
    /// As the SDK declares it: in the type, so that it is mangled as apps import it.
    public init() where Value == Bool { value = false; location = nil; resetValue = false }
    @frozen @propertyWrapper public struct Binding {
        private var _binding: SwiftUI.Binding<Value>
        fileprivate init(_ binding: SwiftUI.Binding<Value>) { _binding = binding }
        public var wrappedValue: Value {
            get { _binding.wrappedValue }
            nonmutating set { _binding.wrappedValue = newValue }
        }
        public var projectedValue: FocusState<Value>.Binding { self }
    }
    internal var value: Value
    internal var location: AnyLocation<Value>?
    internal var resetValue: Value
    public var wrappedValue: Value {
        get { location?.get() ?? value }
        nonmutating set { location?.set(newValue, Transaction()) }
    }
    public var projectedValue: FocusState<Value>.Binding {
        guard let location = location else { return Binding(.constant(value)) }
        return Binding(SwiftUI.Binding(get: location.get, set: location.set))
    }
    public static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer, container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs) {}
}
extension FocusState {
    public init<T>() where Value == T?, T: Hashable { value = nil; location = nil; resetValue = nil }
}
extension FocusState: InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath) {
        let initial = value
        location = graph.location(at: path) { initial }
    }
}

// MARK: - GestureState

@propertyWrapper @frozen public struct GestureState<Value>: DynamicProperty {
    fileprivate var state: State<Value>
    fileprivate let reset: (SwiftUI.Binding<Value>) -> Void
    public init(wrappedValue: Value) {
        self.init(wrappedValue: wrappedValue, resetTransaction: Transaction())
    }
    public init(wrappedValue: Value, resetTransaction: Transaction) {
        state = State(wrappedValue: wrappedValue)
        reset = { $0.wrappedValue = wrappedValue }
    }
    public init(wrappedValue: Value, reset: @escaping (Value, inout Transaction) -> Void) {
        state = State(wrappedValue: wrappedValue)
        self.reset = { binding in
            var transaction = Transaction()
            reset(binding.wrappedValue, &transaction)
            binding.wrappedValue = wrappedValue
        }
    }
    public var wrappedValue: Value { state.wrappedValue }
    public var projectedValue: GestureState<Value> { self }
}
extension GestureState where Value: ExpressibleByNilLiteral {
    public init(resetTransaction: Transaction = Transaction()) {
        self.init(wrappedValue: nil, resetTransaction: resetTransaction)
    }
    public init(reset: @escaping (Value, inout Transaction) -> Void) {
        self.init(wrappedValue: nil, reset: reset)
    }
}

// MARK: - Namespace

@frozen @propertyWrapper public struct Namespace: DynamicProperty {
    @usableFromInline internal var id: Int
    @inlinable public init() { id = 0 }
    public static func _makeProperty<V>(in buffer: inout _DynamicPropertyBuffer, container: _GraphValue<V>, fieldOffset: Int, inputs: inout _GraphInputs) {}
    public var wrappedValue: Namespace.ID { ID(id: id) }
    @frozen public struct ID: Hashable {
        fileprivate var id: Int
        public func hash(into hasher: inout Hasher) { hasher.combine(id) }
        public static func == (a: Namespace.ID, b: Namespace.ID) -> Bool { a.id == b.id }
    }
}
private var nextNamespace = 0
extension Namespace: InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath) {
        id = graph.location(at: path) { () -> Int in nextNamespace += 1; return nextNamespace }.get()
    }
}
