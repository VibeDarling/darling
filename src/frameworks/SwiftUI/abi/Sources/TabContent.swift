// The TabContent API of iOS 18, from the iOS 18.0 SDK's SwiftUI interface. Each tab becomes a view
// carrying a tabItem and a tag, so that TabView arranges it like a tab of the older API.

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public protocol TabContent<TabValue> {
    associatedtype TabValue: Hashable where Self.TabValue == Self.Body.TabValue
    associatedtype _IdentifiedView: View = _TabContentBodyAdaptor<Self>
    var _identifiedView: Self._IdentifiedView { get }
    associatedtype Body: TabContent
    @TabContentBuilder<Self.TabValue> var body: Self.Body { get }
}
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension TabContent where Self._IdentifiedView == _TabContentBodyAdaptor<Self> {
    public var _identifiedView: _TabContentBodyAdaptor<Self> { _TabContentBodyAdaptor(content: self) }
}
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public struct _TabContentBodyAdaptor<C>: View where C: TabContent {
    fileprivate var content: C
    public var body: C.Body._IdentifiedView { content.body._identifiedView }
    public typealias Body = C.Body._IdentifiedView
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@resultBuilder public struct TabContentBuilder<TabValue> where TabValue: Hashable {
    public struct Content<C>: View where C: TabContent {
        fileprivate var content: C
        internal init(_ content: C) { self.content = content }
        public var body: some View { content._identifiedView }
    }
    @_alwaysEmitIntoClient public static func buildExpression(_ content: some TabContent<TabValue>) -> some TabContent<TabValue> { content }
    @_alwaysEmitIntoClient public static func buildBlock(_ content: some TabContent<TabValue>) -> some TabContent<TabValue> { content }
    @_alwaysEmitIntoClient public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> some TabContent<TabValue> where TabValue == C0.TabValue, C0: TabContent, C1: TabContent, C0.TabValue == C1.TabValue {
        return _TupleTabContent<TabValue, (C0._IdentifiedView, C1._IdentifiedView)>((c0._identifiedView, c1._identifiedView))
    }
    @_alwaysEmitIntoClient public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> some TabContent<TabValue> where TabValue == C0.TabValue, C0: TabContent, C1: TabContent, C2: TabContent, C0.TabValue == C1.TabValue, C1.TabValue == C2.TabValue {
        return _TupleTabContent<TabValue, (C0._IdentifiedView, C1._IdentifiedView, C2._IdentifiedView)>((c0._identifiedView, c1._identifiedView, c2._identifiedView))
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
@usableFromInline @frozen internal struct _TupleTabContent<T, U> where T: Hashable {
    @usableFromInline internal typealias TabValue = T
    @usableFromInline internal let _identifiedView: TupleView<U>
    @inlinable internal init(_ content: U) { _identifiedView = .init(content) }
    @usableFromInline internal var body: _TupleTabContent<T, U> { return self }
    @usableFromInline internal typealias Body = _TupleTabContent<T, U>
    @usableFromInline internal typealias _IdentifiedView = TupleView<U>
}
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension _TupleTabContent: TabContent {}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public struct DefaultTabLabel: View {
    fileprivate var title: Text
    fileprivate var image: Image
    public var body: some View { SwiftUI.Label(title: { title }, icon: { image }) }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public struct Tab<Value, Content, Label> {
    fileprivate var value: Value
    fileprivate var content: Content
    fileprivate var label: Label
}
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
extension Tab: TabContent where Value: Hashable, Content: View, Label: View {
    public typealias TabValue = Value
    public init(_ titleKey: LocalizedStringKey, image: String, value: Value, @ViewBuilder content: () -> Content) where Label == DefaultTabLabel {
        self.init(value: value, content: content(), label: DefaultTabLabel(title: Text(titleKey), image: Image(image)))
    }
    public init(_ titleKey: LocalizedStringKey, systemImage: String, value: Value, @ViewBuilder content: () -> Content) where Label == DefaultTabLabel {
        self.init(value: value, content: content(), label: DefaultTabLabel(title: Text(titleKey), image: Image(systemName: systemImage)))
    }
    public var _identifiedView: some View {
        content.tabItem { label }._trait(TagValueTraitKey<Value>.self, .tagged(value))
    }
    public var body: Tab<Value, Content, Label> { return self }
    public typealias Body = Tab<Value, Content, Label>
}
