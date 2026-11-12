// ForEach, List and ScrollView, with the iOS 16.5 SDK's declarations.
import Foundation
import CoreFoundation
import _Concurrency

/// One view per element; each element's views keep their state under the element's identifier.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ForEach<Data, ID, Content> where Data : Swift.RandomAccessCollection, ID : Swift.Hashable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public var data: Data
  public var content: (Data.Element) -> Content
  fileprivate var identify: (Data.Element) -> ID

  fileprivate init(data: Data, identify: @escaping (Data.Element) -> ID, content: @escaping (Data.Element) -> Content) {
    self.data = data; self.identify = identify; self.content = content
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ForEach : DynamicViewContent where Content : View {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ForEach : View where Content : View {
  public typealias Body = Swift.Never
  public static func _makeView(view: _GraphValue<ForEach<Data, ID, Content>>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    var children: [RenderNode] = []
    for element in value.data {
      let elementInputs = inputs.child("forEach").child(AnyHashable(value.identify(element)))
      children += Content._makeView(view: _GraphValue(value: value.content(element)), inputs: elementInputs).renderedNode.list
    }
    return _ViewOutputs(node: RenderNode(kind: "group", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("forEach")) ?? "", children: children))
  }
  public static func _makeViewList(view: _GraphValue<ForEach<Data, ID, Content>>, inputs: _ViewListInputs) -> _ViewListOutputs {
    _ViewListOutputs(view: _makeView(view: view, inputs: inputs.viewInputs))
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ForEach where ID == Data.Element.ID, Content : View, Data.Element : Swift.Identifiable {
  public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
    self.init(data: data, identify: { $0.id }, content: content)
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ForEach where Content : View {
  public init(_ data: Data, id: Swift.KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
    self.init(data: data, identify: { $0[keyPath: id] }, content: content)
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ForEach where Data == Swift.Range<Swift.Int>, ID == Swift.Int, Content : View {
  @_semantics("swiftui.requires_constant_range") public init(_ data: Swift.Range<Swift.Int>, @ViewBuilder content: @escaping (Swift.Int) -> Content) {
    self.init(data: data, identify: { $0 }, content: content)
  }
}

/// Rows in a vertical scroll view, without separators, selection or editing.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@preconcurrency @MainActor public struct List<SelectionValue, Content> : View where SelectionValue : Swift.Hashable, Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var content: Content
  fileprivate init(content: Content) { self.content = content }
  @available(watchOS, unavailable)
  @preconcurrency @MainActor public init(selection: Binding<Swift.Set<SelectionValue>>?, @ViewBuilder content: () -> Content) { self.init(content: content()) }
  @available(watchOS, unavailable)
  @preconcurrency @MainActor public init(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> Content) { self.init(content: content()) }
  @available(macOS 13.0, *)
  @available(iOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  @_disfavoredOverload @preconcurrency @MainActor public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) { self.init(content: content()) }
  @preconcurrency @MainActor public var body: some View {
    ScrollView { VStack(alignment: .leading, spacing: 0) { content } }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension List where SelectionValue == Swift.Never {
  @preconcurrency @MainActor public init(@ViewBuilder content: () -> Content) { self.init(content: content()) }
}

/// A UIScrollView around its content, which takes its ideal size along the scrolling axes.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ScrollView<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public var content: Content
  public var axes: Axis.Set
  public var showsIndicators: Swift.Bool
  public init(_ axes: Axis.Set = .vertical, showsIndicators: Swift.Bool = true, @ViewBuilder content: () -> Content) {
    self.axes = axes; self.showsIndicators = showsIndicators; self.content = content()
  }
  @preconcurrency @MainActor public var body: some View {
    ScrollViewRoot(content: content, axes: axes, showsIndicators: showsIndicators)
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension ScrollView {
  public var _alwaysBounceAxes: Axis.Set {
    get { [] }
    set {}
  }
}

private struct ScrollViewRoot<Content: View>: View {
  let content: Content
  let axes: Axis.Set
  let showsIndicators: Bool
  typealias Body = Never
  var body: Never { fatalError() }
  static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    let child = Content._makeView(view: _GraphValue(value: value.content), inputs: inputs.child("scrollContent"))
    // Several views scroll as a stack along the scrolling axis.
    var content = child.renderedNode
    let views = content.list
    if views.count != 1 {
      content = RenderNode(kind: value.axes == .horizontal ? "hstack" : "vstack", children: views)
    }
    var node = RenderNode(kind: "scroll", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("scroll")) ?? "",
                          children: [content])
    node.properties["axes"] = (value.axes.contains(.horizontal) ? "h" : "") + (value.axes.contains(.vertical) ? "v" : "")
    node.properties["indicators"] = value.showsIndicators ? "true" : "false"
    return _ViewOutputs(node: node)
  }
}
