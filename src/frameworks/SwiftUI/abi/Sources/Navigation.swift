import Foundation
public struct NavigationPath: Equatable {
    private var elements: [AnyHashable] = []
    public init() {}
    public init<S: Sequence>(_ elements: S) where S.Element: Hashable { self.elements = elements.map(AnyHashable.init) }
    public init<S: Sequence>(_ elements: S) where S.Element: Hashable & Codable { self.elements = elements.map(AnyHashable.init) }
    public var count: Int { elements.count }
    public var isEmpty: Bool { elements.isEmpty }
    public mutating func append<V: Hashable>(_ value: V) { elements.append(AnyHashable(value)) }
    public mutating func append<V: Hashable & Codable>(_ value: V) { elements.append(AnyHashable(value)) }
    public mutating func removeLast(_ k: Int = 1) { elements.removeLast(k) }
}
public struct NavigationStack<Data, Root: View>: View {
    private let root: Root
    private let path: Binding<Data>?
    public init(@ViewBuilder root: () -> Root) where Data == NavigationPath {
        self.root = root()
        path = nil
    }
    public init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) where Data == NavigationPath {
        self.path = path
        self.root = root()
    }
    public init(path: Binding<Data>, @ViewBuilder root: () -> Root)
    where Data: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, Data.Element: Hashable {
        self.path = path
        self.root = root()
    }
    public var body: some View { root }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        if let path = view.value.path?.wrappedValue {
            let empty = (path as? NavigationPath)?.isEmpty ?? (path as? any Collection)?.isEmpty ?? true
            if !empty, reportedModifiers.insert("NavigationStack(path:)").inserted {
                fputs("SwiftUI: navigation paths are not implemented; the root is shown\n", stderr)
            }
        }
        return _darlingNavigationContainer(root: AnyView(view.value.root), inputs: inputs)
    }
}
@frozen public struct IDView<Content: View, ID: Hashable>: View {
    @usableFromInline var content: Content
    @usableFromInline var id: ID
    @inlinable public init(_ content: Content, id: ID) { self.content = content; self.id = id }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        Content._makeView(view: _GraphValue(value: view.value.content), inputs: inputs.child("id").child(AnyHashable(view.value.id)))
    }
}
extension View {
    public func id<ID: Hashable>(_ id: ID) -> some View { IDView(self, id: id) }
}
