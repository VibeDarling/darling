@_spi(Reflection) import Swift
import Foundation
@_spi(SwiftUI) import Observation
import Combine
import _Concurrency

struct ViewPath: Hashable {
    var components: [AnyHashable] = []
    func child(_ component: AnyHashable) -> Self {
        Self(components: components + [component])
    }
}

protocol InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath)
    static func install(at pointer: UnsafeMutableRawPointer, graph: ViewGraph, path: ViewPath)
}
extension InstalledProperty {
    static func install(at pointer: UnsafeMutableRawPointer, graph: ViewGraph, path: ViewPath) {
        pointer.assumingMemoryBound(to: Self.self).pointee.install(in: graph, at: path)
    }
}

private final class StateCell<Value> {
    private let lock = NSRecursiveLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    func get() -> Value { lock.lock(); defer { lock.unlock() }; return value }
    /// Stores `value`; false if it equals the stored one, which, as in SwiftUI, needs no update.
    func set(_ value: Value) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let changed = !_darlingValuesEqual(self.value, value)
        self.value = value
        return changed
    }
}

/// Whether two values are equal, for Equatable types; other values always count as changed.
func _darlingValuesEqual<Value>(_ lhs: Value, _ rhs: Value) -> Bool {
    func equal<T: Equatable>(_ lhs: T, _ rhs: Any) -> Bool { (rhs as? T) == lhs }
    guard let lhs = lhs as? any Equatable else { return false }
    return equal(lhs, rhs)
}

private struct StateEntry { let location: AnyObject; var generation: Int }
private struct TaskEntry {
    let identity: Any
    let equal: (Any) -> Bool
    let start: () -> Task<Void, Never>
    var task: Task<Void, Never>?
    var generation: Int
}


var applicationGraph: ViewGraph?
func refreshApplicationGraph() {
    guard let graph = applicationGraph else { return }
    sendRenderTree(graph.update())
    darlingUpdate()
}

final class ViewGraph {
    var render: (() -> _SceneOutputs)!
    /// How a graph other than the application's (a hosting controller's) brings itself up to date.
    var refresh: (() -> Void)?
    private var generation = 0
    private var states: [ViewPath: StateEntry] = [:]
    private var nodeIDs: [ViewPath: (value: UInt64, generation: Int)] = [:]
    /// Shared by every graph, so that identities (which name button actions) are unique among
    /// the app's graph and those of its hosting controllers.
    private static var nextNodeID: UInt64 = 0
    private var tasks: [ViewPath: TaskEntry] = [:]
    private var subscriptions: [ViewPath: (generation: Int, value: AnyCancellable)] = [:]
    private var appeared: [ViewPath: (generation: Int, disappear: (() -> Void)?)] = [:]
    private var lastValues: [ViewPath: (generation: Int, value: Any)] = [:]
    private var pendingActions: [() -> Void] = []
    private var geometry: [ViewPath: CGRect] = [:]
    private let updateLock = NSLock()
    private var scheduled = false
    private var launched = false
    var phase = ScenePhase.inactive
    var currentEnvironment: EnvironmentValues?
    var environmentKeyPaths: [ViewPath: AnyKeyPath] = [:]

    private var reportedInvalidations = 0
    func invalidate(_ reason: @autoclosure () -> String = "other") {
        if getenv("DARLING_SWIFTUI_DUMP") != nil && reportedInvalidations < 60 {
            reportedInvalidations += 1
            fputs("SwiftUI: invalidated by \(reason()) during generation \(generation)\n", stderr)
        }
        updateLock.lock()
        let enqueue = !scheduled
        scheduled = true
        updateLock.unlock()
        guard enqueue else { return }
        if let refresh = refresh {
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) { refresh() }
            CFRunLoopWakeUp(CFRunLoopGetMain())
        } else {
            darlingScheduleUpdate(refreshApplicationGraph)
        }
    }
    func beginUpdate() {
        updateLock.lock(); scheduled = false; updateLock.unlock()
    }
    func evaluate() -> _SceneOutputs {
        generation += 1
        let started = CFAbsoluteTimeGetCurrent()
        defer {
            if getenv("DARLING_SWIFTUI_DUMP") != nil && (generation % 20 == 0 || CFAbsoluteTimeGetCurrent() - started > 1) {
                fputs("SwiftUI: evaluation \(generation) took \(Int((CFAbsoluteTimeGetCurrent() - started) * 1000)) ms at \(Int(started) % 1000)\n", stderr)
            }
        }
        clearOpenURLHandlers()
        clearButtonActions(self)
        let output = withObservationTracking({ render() }, didSet: { [weak self] tracking in
            tracking.cancel()
            self?.invalidate("observation tracking")
        })
        states = states.filter { $0.value.generation == generation }
        nodeIDs = nodeIDs.filter { $0.value.generation == generation }
        subscriptions = subscriptions.filter { $0.value.generation == generation }
        for (path, entry) in appeared where entry.generation != generation {
            appeared.removeValue(forKey: path)
            if let disappear = entry.disappear { pendingActions.append(disappear) }
        }
        lastValues = lastValues.filter { $0.value.generation == generation }
        for path in Array(tasks.keys) where tasks[path]!.generation != generation {
            tasks.removeValue(forKey: path)?.task?.cancel()
        }
        if launched { startPendingTasks() }
        return output
    }
    func launch() {
        launched = true
        phase = .active
        startPendingTasks()
        invalidate()
    }
    private func startPendingTasks() {
        for path in Array(tasks.keys) where tasks[path]!.task == nil {
            let start = tasks[path]!.start
            tasks[path]!.task = start()
        }
    }
    func task<Identity: Equatable>(at path: ViewPath, identity: Identity,
                                  start: @escaping () -> Task<Void, Never>) {
        if var old = tasks[path], old.equal(identity) {
            old.generation = generation
            tasks[path] = old
        } else {
            tasks[path]?.task?.cancel()
            tasks[path] = TaskEntry(identity: identity, equal: { ($0 as? Identity) == identity },
                                    start: start, generation: generation)
        }
    }
    /// The frame the GeometryReader at `path` was last laid out in (in the window), if it has been.
    func geometry(at path: ViewPath) -> CGRect? { geometry[path] }
    /// Records a GeometryReader's frame; a change (beyond rounding) updates the graph.
    func reportGeometry(_ frame: CGRect, at path: ViewPath) {
        if let old = geometry[path], abs(old.minX - frame.minX) < 0.5, abs(old.minY - frame.minY) < 0.5,
           abs(old.width - frame.width) < 0.5, abs(old.height - frame.height) < 0.5 { return }
        geometry[path] = frame
        invalidate("geometry \(frame) at \(path.components.suffix(4))")
    }
    /// Queues `appear` the first time a view is evaluated at `path`; `disappear` runs once an
    /// update no longer evaluates it.
    func appearance(at path: ViewPath, appear: (() -> Void)?, disappear: (() -> Void)?) {
        if appeared[path] == nil, let appear = appear { pendingActions.append(appear) }
        appeared[path] = (generation, disappear)
    }
    /// Queues `action` with `value` the first time it is seen at `path` and whenever it changes.
    func initialOrChangedValue<Value: Equatable>(at path: ViewPath, value: Value, action: @escaping (Value) -> Void) {
        if lastValues[path]?.value as? Value != value { pendingActions.append { action(value) } }
        lastValues[path] = (generation, value)
    }
    /// Queues `action` with the new value when `value` differs from the previous update's.
    func valueChange<Value: Equatable>(at path: ViewPath, value: Value, action: @escaping (Value) -> Void) {
        if let old = lastValues[path]?.value as? Value, old != value { pendingActions.append { action(value) } }
        lastValues[path] = (generation, value)
    }
    /// Evaluates the graph, then runs the onAppear, onDisappear and onChange actions the evaluation
    /// queued; as in SwiftUI they run before the result is laid out, so what they change is
    /// evaluated again first (a few rounds at most), and layout never sees state behind its views.
    func update() -> _SceneOutputs {
        // (Initialized before the loop: swiftc 6.3.3 -O destroyed the uninitialized result of a
        // `var output: _SceneOutputs` assigned in a repeat loop.)
        beginUpdate()
        var output = evaluate()
        runQueuedActions()
        var rounds = 1
        while rounds < 8 && isScheduled {
            beginUpdate()
            output = evaluate()
            runQueuedActions()
            rounds += 1
        }
        return output
    }
    private func runQueuedActions() {
        let actions = pendingActions
        pendingActions = []
        actions.forEach { $0() }
    }
    private var isScheduled: Bool { updateLock.lock(); defer { updateLock.unlock() }; return scheduled }
    func subscription(at path: ViewPath, create: () -> AnyCancellable) {
        subscriptions.removeValue(forKey: path)?.value.cancel()
        subscriptions[path] = (generation, create())
    }
    func nodeIdentity(at path: ViewPath) -> String {
        if var identity = nodeIDs[path] {
            identity.generation = generation
            nodeIDs[path] = identity
            return String(identity.value)
        }
        Self.nextNodeID += 1
        nodeIDs[path] = (Self.nextNodeID, generation)
        return String(Self.nextNodeID)
    }
    func location<Value>(at path: ViewPath, initial: () -> Value) -> AnyLocation<Value> {
        if var entry = states[path], let location = entry.location as? AnyLocation<Value> {
            entry.generation = generation
            states[path] = entry
            return location
        }
        let cell = StateCell(initial())
        let location = AnyLocation(get: { cell.get() }, set: { [weak self] value, _ in
            if cell.set(value) { self?.invalidate("state at \(path)") }
        })
        states[path] = StateEntry(location: location, generation: generation)
        return location
    }
    func install<Value>(_ value: inout Value, at path: ViewPath, environment: EnvironmentValues? = nil) {
        let old = currentEnvironment
        if let environment = environment { currentEnvironment = environment }
        defer { currentEnvironment = old }
        withUnsafeMutablePointer(to: &value) { pointer in
            install(type: Value.self, at: UnsafeMutableRawPointer(pointer), path: path)
        }
    }
    private func install(type: Any.Type, at pointer: UnsafeMutableRawPointer, path: ViewPath) {
        _forEachField(of: type, options: .ignoreUnknown) { name, offset, fieldType, _ in
            let fieldPath = path.child(String(cString: name))
            if let property = fieldType as? any InstalledProperty.Type {
                property.install(at: pointer.advanced(by: offset), graph: self, path: fieldPath)
            } else if let property = fieldType as? any DynamicProperty.Type {
                let field = pointer.advanced(by: offset)
                install(type: fieldType, at: field, path: fieldPath)
                func update<Property: DynamicProperty>(_ type: Property.Type) {
                    field.assumingMemoryBound(to: Property.self).pointee.update()
                }
                _openExistential(property, do: update)
            }
            return true
        }
    }
}

extension State: InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath) {
        _location = graph.location(at: path) { _value }
    }
}
extension LazyState: InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath) {
        let location = graph.location(at: path) { _storage.value }
        _location = location
        _storage = .value(location.get())
    }
}
extension Environment: InstalledProperty {
    mutating func install(in graph: ViewGraph, at path: ViewPath) {
        if case .keyPath(let keyPath) = content { graph.environmentKeyPaths[path] = keyPath }
        if let keyPath = graph.environmentKeyPaths[path] as? KeyPath<EnvironmentValues, Value> {
            var values = graph.currentEnvironment ?? EnvironmentValues()
            if graph.currentEnvironment == nil { values.scenePhase = graph.phase }
            content = .value(values[keyPath: keyPath])
        }
    }
}
