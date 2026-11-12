import Darwin
import Observation
import _Concurrency

// The scope covers body evaluation and is captured again for event callbacks.
// It is thread-local so a worker notification cannot overwrite a UI evaluation.
enum EnvironmentScope {
    // Async actions can resume on another thread. Their environment must follow
    // the task rather than remaining installed in a thread's synchronous scope.
    @TaskLocal static var taskObjects: [ObjectIdentifier: AnyObject]? = nil
    private final class Snapshot {
        let objects: [ObjectIdentifier: AnyObject]
        init(_ objects: [ObjectIdentifier: AnyObject]) { self.objects = objects }
    }
    private static let key: pthread_key_t = {
        var key: pthread_key_t = 0
        precondition(pthread_key_create(&key, nil) == 0)
        return key
    }()
    static var objects: [ObjectIdentifier: AnyObject] {
        guard let value = pthread_getspecific(key) else { return taskObjects ?? [:] }
        return Unmanaged<Snapshot>.fromOpaque(value).takeUnretainedValue().objects
    }
    static func withObjects<Result>(_ objects: [ObjectIdentifier: AnyObject], _ body: () throws -> Result) rethrows -> Result {
        let old = pthread_getspecific(key)
        let snapshot = Unmanaged.passRetained(Snapshot(objects))
        precondition(pthread_setspecific(key, snapshot.toOpaque()) == 0)
        defer { pthread_setspecific(key, old); snapshot.release() }
        return try body()
    }
}
@available(iOS 17.0, *)
private struct ObservableKey<Value: AnyObject & Observable>: EnvironmentKey, Hashable {
    static var defaultValue: Value? { EnvironmentScope.objects[ObjectIdentifier(Value.self)] as? Value }
}
@available(iOS 17.0, *)
extension EnvironmentValues {
    fileprivate subscript<Value: AnyObject & Observable>(required key: ObservableKey<Value>) -> Value {
        guard let value = self[ObservableKey<Value>.self] else {
            fatalError("SwiftUI: no observable object of type \(Value.self) in the environment")
        }
        return value
    }
    fileprivate subscript<Value: AnyObject & Observable>(optional key: ObservableKey<Value>) -> Value? {
        self[ObservableKey<Value>.self]
    }
}
@available(iOS 17.0, *)
extension Environment {
    public init(_ objectType: Value.Type) where Value: AnyObject & Observable {
        self.init(\EnvironmentValues[required: ObservableKey<Value>()])
    }
    public init<T>(_ objectType: T.Type) where Value == T?, T: AnyObject & Observable {
        self.init(\EnvironmentValues[optional: ObservableKey<T>()])
    }
}
@available(iOS 17.0, *)
private struct ObjectEnvironmentView<Content: View, Value: AnyObject & Observable>: View {
    let content: Content
    let object: Value?
    typealias Body = Never
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        var inputs = inputs
        inputs.objects[ObjectIdentifier(Value.self)] = view.value.object
        return Content._makeView(view: _GraphValue(value: view.value.content), inputs: inputs)
    }
}
@available(iOS 17.0, *)
extension View {
    public func environment<T>(_ object: T?) -> some View where T: AnyObject & Observable {
        ObjectEnvironmentView(content: self, object: object)
    }
}
