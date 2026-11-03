import CoreData
import Foundation
import Combine
import _Concurrency
import DarlingCoreDataBridge

private struct ManagedObjectContextKey: EnvironmentKey {
    static var defaultValue: NSManagedObjectContext? { nil }
}
extension EnvironmentValues {
    public var managedObjectContext: NSManagedObjectContext {
        get {
            guard let context = self[ManagedObjectContextKey.self] else {
                preconditionFailure("A managed object context must be supplied in the environment")
            }
            return context
        }
        set { self[ManagedObjectContextKey.self] = newValue }
    }
}

public struct FetchedResults<Result>: RandomAccessCollection where Result: NSFetchRequestResult {
    public typealias Element = Result
    public typealias Index = Int
    public typealias Indices = Range<Int>
    public typealias Iterator = IndexingIterator<FetchedResults<Result>>
    public typealias SubSequence = Slice<FetchedResults<Result>>
    private let values: [Result]
    fileprivate init(_ values: [Result]) { self.values = values }
    public var startIndex: Int { values.startIndex }
    public var endIndex: Int { values.endIndex }
    public subscript(position: Int) -> Result { values[position] }
    public func index(after index: Int) -> Int { index + 1 }
    public func index(before index: Int) -> Int { index - 1 }
}

private struct FetchConfiguration {
    var entity: NSEntityDescription
    var sort: [NSSortDescriptor]
    var predicate: NSPredicate?
    var animation: Animation?
    func matches(_ other: Self) -> Bool {
        guard entity === other.entity, sort.count == other.sort.count, animation == other.animation else { return false }
        guard predicate === other.predicate || predicate?.isEqual(other.predicate) == true else { return false }
        return zip(sort, other.sort).allSatisfy { left, right in
            left === right || (left.key != nil && left.key == right.key && left.ascending == right.ascending && left.selector == right.selector)
        }
    }
}
private final class FetchState<Result: NSFetchRequestResult> {
    var context: NSManagedObjectContext?
    var values: [Result] = []
    var initial: FetchConfiguration
    var configuration: FetchConfiguration
    var invalidate: (() -> Void)?
    init(_ configuration: FetchConfiguration) {
        initial = configuration
        self.configuration = configuration
    }
    func refresh() {
        guard let context = context else { preconditionFailure("FetchRequest used before graph installation") }
        guard let objects = DarlingContextFetch(context, configuration.entity, configuration.sort, configuration.predicate),
              let results = objects as? [Result] else {
            preconditionFailure("The managed object fetch failed")
        }
        values = results
    }
}

@propertyWrapper @MainActor(unsafe) public struct FetchRequest<Result>: DynamicProperty where Result: NSFetchRequestResult {
    public struct Configuration {
        fileprivate var value: FetchConfiguration
    }
    private let initial: FetchConfiguration
    private var state: FetchState<Result>
    public init(entity: NSEntityDescription, sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil,
                animation: Animation? = nil) {
        initial = FetchConfiguration(entity: entity, sort: sortDescriptors, predicate: predicate, animation: animation)
        state = FetchState(initial)
    }
    public var wrappedValue: FetchedResults<Result> {
        guard state.context != nil else { preconditionFailure("FetchRequest used before graph installation") }
        return FetchedResults(state.values)
    }
    public var projectedValue: Binding<Configuration> {
        let current = state
        return Binding(get: { Configuration(value: current.configuration) }, set: { value in
            current.configuration = value.value
            current.invalidate?()
        })
    }
    public mutating func update() {}
    public static var _propertyBehaviors: UInt32 { 0 }
}

extension FetchRequest: InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath) {
        let created = state
        state = graph.location(at: path) { created }.get()
        if !state.initial.matches(initial) {
            state.initial = initial
            state.configuration = initial
        }
        state.context = (graph.currentEnvironment ?? EnvironmentValues()).managedObjectContext
        state.invalidate = { [weak graph] in graph?.invalidate("fetch configuration") }
        state.refresh()
        let context = state.context!
        graph.subscription(at: path.child("managedObjects")) {
            let observer = DarlingContextObservation(context: context) { [weak graph] in
                graph?.invalidate("managed object changes")
            }
            return AnyCancellable { observer.cancel() }
        }
    }
}
