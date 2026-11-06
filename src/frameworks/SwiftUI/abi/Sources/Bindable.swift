// Bindable, from the iOS 18.0 SDK's SwiftUICore interface. It is not frozen: only its accessors and
// initializers are ABI, and it holds the wrapped reference.
import Observation

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@dynamicMemberLookup @propertyWrapper public struct Bindable<Value> {
    public var wrappedValue: Value
    public var projectedValue: Bindable<Value> { self }
    @available(*, unavailable, message: "The wrapped value must be an object that conforms to Observable")
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    @available(*, unavailable, message: "The wrapped value must be an object that conforms to Observable")
    public init(projectedValue: Bindable<Value>) { self = projectedValue }
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension Bindable where Value: AnyObject {
    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> {
        let object = wrappedValue
        return Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
    }
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension Bindable where Value: AnyObject, Value: Observation.Observable {
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(_ wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(projectedValue: Bindable<Value>) { self = projectedValue }
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension Bindable: Identifiable where Value: Identifiable {
    public var id: Value.ID { wrappedValue.id }
    public typealias ID = Value.ID
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension Bindable: Sendable where Value: Sendable {}
