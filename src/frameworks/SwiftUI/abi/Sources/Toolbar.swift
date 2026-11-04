import Foundation
public struct _ToolbarInputs { var viewInputs = _ViewInputs() }
public struct _ToolbarOutputs {
    /// The items, made, with where each goes: "leading", "principal" or "trailing".
    var items: [(placement: String, node: RenderNode)] = []
    var labels: [String] { items.map(\.node.plainText) }
}
public struct _ToolbarItemList { var labels: [String] = [] }

public protocol ToolbarContent {
    associatedtype Body: ToolbarContent
    @ToolbarContentBuilder var body: Body { get }
    static func _makeToolbar(content: _GraphValue<Self>, inputs: _ToolbarInputs) -> _ToolbarOutputs
    static func _makeContent(content: _GraphValue<Self>, inputs: _GraphInputs, resolved: inout _ToolbarItemList)
}
public protocol CustomizableToolbarContent: ToolbarContent where Body: CustomizableToolbarContent {}
extension Never: ToolbarContent, CustomizableToolbarContent {}
extension ToolbarContent {
    public static func _makeToolbar(content: _GraphValue<Self>, inputs: _ToolbarInputs) -> _ToolbarOutputs {
        // As for a view: the content's dynamic properties (@Environment, @State, ...) are set up
        // before its body is read.
        var value = content.value
        var inputs = inputs
        inputs.viewInputs = inputs.viewInputs.child(ObjectIdentifier(Self.self))
        let viewInputs = inputs.viewInputs
        viewInputs.graph?.install(&value, at: viewInputs.path, environment: viewInputs.environment)
        inputs.viewInputs = viewInputs.child("body")
        return EnvironmentScope.withObjects(viewInputs.objects) {
            Body._makeToolbar(content: _GraphValue(value: value.body), inputs: inputs)
        }
    }
    public static func _makeContent(content: _GraphValue<Self>, inputs: _GraphInputs, resolved: inout _ToolbarItemList) {
        resolved.labels += _makeToolbar(content: content, inputs: _ToolbarInputs()).labels
    }
}
@resultBuilder public struct ToolbarContentBuilder {
    public static func buildExpression<Content: ToolbarContent>(_ content: Content) -> Content { content }
    public static func buildBlock<Content: ToolbarContent>(_ content: Content) -> some ToolbarContent { content }
    public static func buildExpression<Content: CustomizableToolbarContent>(_ content: Content) -> Content { content }
    public static func buildBlock<Content: CustomizableToolbarContent>(_ content: Content) -> some CustomizableToolbarContent { content }
    public static func buildEither<TrueContent: ToolbarContent, FalseContent: ToolbarContent>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(toolbarStorage: .trueContent(first))
    }
    public static func buildEither<TrueContent: ToolbarContent, FalseContent: ToolbarContent>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(toolbarStorage: .falseContent(second))
    }
    public static func buildEither<TrueContent: CustomizableToolbarContent, FalseContent: CustomizableToolbarContent>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(toolbarStorage: .trueContent(first))
    }
    public static func buildEither<TrueContent: CustomizableToolbarContent, FalseContent: CustomizableToolbarContent>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(toolbarStorage: .falseContent(second))
    }
}
extension _ConditionalContent {
    init(toolbarStorage: Storage) { storage = toolbarStorage }
}
extension _ConditionalContent: ToolbarContent where TrueContent: ToolbarContent, FalseContent: ToolbarContent {
    public var body: Never { return fatalError("SwiftUI: primitive toolbar body") }
    public static func _makeToolbar(content: _GraphValue<Self>, inputs: _ToolbarInputs) -> _ToolbarOutputs {
        switch content.value.storage {
        case .trueContent(let value): return TrueContent._makeToolbar(content: _GraphValue(value: value), inputs: inputs)
        case .falseContent(let value): return FalseContent._makeToolbar(content: _GraphValue(value: value), inputs: inputs)
        }
    }
}
extension _ConditionalContent: CustomizableToolbarContent where TrueContent: CustomizableToolbarContent, FalseContent: CustomizableToolbarContent {}
public struct ToolbarItemPlacement {
    private let value: UInt8
    public static let automatic = Self(value: 0)
    public static let principal = Self(value: 1)
    public static let navigation = Self(value: 2)
    public static let primaryAction = Self(value: 3)
    public static let secondaryAction = Self(value: 4)
    public static let status = Self(value: 5)
    public static let confirmationAction = Self(value: 6)
    public static let cancellationAction = Self(value: 7)
    public static let destructiveAction = Self(value: 8)
    public static let keyboard = Self(value: 9)
    public static let navigationBarLeading = Self(value: 10)
    public static let navigationBarTrailing = Self(value: 11)
    public static let bottomBar = Self(value: 12)
    public static let topBarLeading = Self(value: 13)
    public static let topBarTrailing = Self(value: 14)
    /// Where Darling's navigation bar shows an item so placed; nil where it has no place for it.
    var barPosition: String? {
        switch value {
        case 1: return "principal"
        case 2, 7, 10, 13: return "leading"
        case 5, 9, 12: return nil
        default: return "trailing"
        }
    }
}
public struct ToolbarItem<ID, Content: View>: ToolbarContent {
    let placement: ToolbarItemPlacement
    let content: Content
    public typealias Body = Never
    public var body: Never { return fatalError("SwiftUI: primitive toolbar body") }
    public static func _makeToolbar(content: _GraphValue<Self>, inputs: _ToolbarInputs) -> _ToolbarOutputs {
        guard let position = content.value.placement.barPosition else { return _ToolbarOutputs() }
        var itemInputs = inputs.viewInputs
        if itemInputs.foreground.isEmpty { itemInputs.foreground = [Color.accentColor.resolve(inputs.viewInputs)] }
        let node = Content._makeView(view: _GraphValue(value: content.value.content), inputs: itemInputs).renderedNode
        return _ToolbarOutputs(items: [(position, node)])
    }
}
extension ToolbarItem where ID == () {
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.content = content()
    }
}
/// What ToolbarContentBuilder makes of several items (its buildBlock is emitted into apps).
@usableFromInline internal struct TupleToolbarContent<T>: ToolbarContent, CustomizableToolbarContent {
    let value: T
    @usableFromInline internal init(_ value: T) { self.value = value }
    @usableFromInline internal var body: Never { return fatalError("SwiftUI: primitive toolbar body") }
    @usableFromInline internal static func _makeToolbar(content: _GraphValue<TupleToolbarContent<T>>, inputs: _ToolbarInputs) -> _ToolbarOutputs {
        var outputs = _ToolbarOutputs()
        for (index, field) in Mirror(reflecting: content.value.value).children.enumerated() {
            guard let item = field.value as? any ToolbarContent else { continue }
            var itemInputs = inputs
            itemInputs.viewInputs = inputs.viewInputs.child("toolbar-item").child(index)
            func make<Item: ToolbarContent>(_ item: Item) -> _ToolbarOutputs { Item._makeToolbar(content: _GraphValue(value: item), inputs: itemInputs) }
            outputs.items += make(item).items
        }
        return outputs
    }
    @usableFromInline internal static func _makeContent(content: _GraphValue<TupleToolbarContent<T>>, inputs: _GraphInputs, resolved: inout _ToolbarItemList) {
        resolved.labels += _makeToolbar(content: content, inputs: _ToolbarInputs()).labels
    }
}
extension Optional: ToolbarContent where Wrapped: ToolbarContent {
    public static func _makeToolbar(content: _GraphValue<Optional<Wrapped>>, inputs: _ToolbarInputs) -> _ToolbarOutputs {
        guard let item = content.value else { return _ToolbarOutputs() }
        return Wrapped._makeToolbar(content: _GraphValue(value: item), inputs: inputs)
    }
    public typealias Body = Never
    public var body: Never { return fatalError("SwiftUI: primitive toolbar body") }
}
extension Optional: CustomizableToolbarContent where Wrapped: CustomizableToolbarContent {}
extension ToolbarContentBuilder {
    public static func buildIf<Content>(_ content: Content?) -> Content? where Content: ToolbarContent { content }
    public static func buildIf<Content>(_ content: Content?) -> Content? where Content: CustomizableToolbarContent { content }
}
private struct ToolbarView<Content: View, Items: ToolbarContent>: View {
    let content: Content
    let items: Items
    typealias Body = Never
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        var content = Content._makeView(view: _GraphValue(value: view.value.content), inputs: inputs)
        let toolbar = Items._makeToolbar(content: _GraphValue(value: view.value.items), inputs: _ToolbarInputs(viewInputs: inputs.child("toolbar")))
        // The navigation container this view is in shows the items in its bar.
        content.node.toolbarItems += toolbar.items
        content.node.keepTraits()
        return content
    }
}
extension View {
    public func toolbar<Content: ToolbarContent>(@ToolbarContentBuilder content: () -> Content) -> some View {
        ToolbarView(content: self, items: content())
    }
}
