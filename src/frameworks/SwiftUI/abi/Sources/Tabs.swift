// TabView, tabItem and tag, with the iOS 16.5 SDK's declarations.
import Foundation
import UIKit

/// A view that is already rendered, for containers that arrange the views they made.
struct _RenderedNode: View {
  let node: RenderNode
  typealias Body = Never
  static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs { _ViewOutputs(node: view.value.node) }
}

/// Traits that tag a view (tag(_:)), which TabView and Picker match against their selection.
protocol _DarlingTagTrait { static func _darlingTag(_ value: Any) -> AnyHashable? }
extension TagValueTraitKey: _DarlingTagTrait {
  static func _darlingTag(_ value: Any) -> AnyHashable? {
    guard let value = value as? Value, case .tagged(let tag) = value else { return nil }
    return AnyHashable(tag)
  }
}
extension RenderNode {
  /// Marks a node that carries a trait, so that a list of views does not flatten it away.
  mutating func keepTraits() {
    if kind == "group" && properties.isEmpty { properties["traits"] = "1" }
  }
  /// The node, and those it wraps alone, outermost first: where modifiers applied after a trait put it.
  var traitCarriers: [RenderNode] {
    var result = [self]
    while let last = result.last, last.children.count == 1 { result.append(last.children[0]) }
    return result
  }
}

private struct TabItemModifier<Label: View>: ViewModifier {
  let label: Label
  typealias Body = Never
  static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
      body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
    var outputs = body(_Graph(), inputs)
    let label = modifier.value.label
    outputs.node.tabItem = { inputs in Label._makeView(view: _GraphValue(value: label), inputs: inputs) }
    outputs.node.keepTraits()
    return outputs
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 7.0, *)
extension View {
  public func tabItem<V>(@ViewBuilder _ label: () -> V) -> some View where V : View {
    modifier(TabItemModifier(label: label()))
  }
}

private struct PagedTabsKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
  var _darlingPagedTabs: Bool {
    get { self[PagedTabsKey.self] }
    set { self[PagedTabsKey.self] = newValue }
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension View {
  public func tabViewStyle<S>(_ style: S) -> some View where S : TabViewStyle {
    environment(\._darlingPagedTabs, style is PageTabViewStyle)
  }
}

/// The selected tab above a bar with a button for each tab (its tabItem label). In the page
/// style there is no bar, and pages are not swiped between.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 7.0, *)
public struct TabView<SelectionValue, Content> : View where SelectionValue : Swift.Hashable, Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var selection: Binding<SelectionValue>?
  private var content: Content
  public init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) {
    self.selection = selection
    self.content = content()
  }
  public typealias Body = Never
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    // Every tab is made (so that each keeps its state), and the selected one is shown.
    let tabs = Content._makeView(view: _GraphValue(value: value.content), inputs: inputs.child("tabs")).renderedNode.list
    func tags(_ index: Int) -> [AnyHashable] { tabs[index].traitCarriers.flatMap(\.tags) }
    let ownSelection = inputs.graph?.location(at: inputs.path.child("tab-selection"), initial: { 0 })
    var selected = 0
    if let binding = value.selection {
      let current = AnyHashable(binding.wrappedValue)
      selected = tabs.indices.first { tags($0).contains(current) } ?? 0
    } else if let ownSelection = ownSelection {
      selected = min(ownSelection.get(), max(tabs.count - 1, 0))
    }
    let page = tabs.isEmpty ? RenderNode(kind: "empty") : tabs[selected]
    if inputs.environment._darlingPagedTabs {
      if tabs.count > 1, reportedModifiers.insert("PageTabViewStyle").inserted {
        fputs("SwiftUI: TabView pages cannot be swiped between; the selected page is shown\n", stderr)
      }
      return _ViewOutputs(node: page)
    }
    func select(_ index: Int) {
      if let binding = value.selection {
        for tag in tags(index) {
          if let tag = tag.base as? SelectionValue { binding.wrappedValue = tag; return }
        }
      } else {
        ownSelection?.set(index, Transaction())
      }
    }
    let labels = tabs.map { tab in tab.traitCarriers.lazy.compactMap(\.tabItem).first }
    let chrome = VStack(spacing: 0) {
      _RenderedNode(node: page).frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider()
      HStack(spacing: 0) {
        ForEach(0..<tabs.count, id: \.self) { index in
          Button { select(index) } label: {
            TabBarItem(label: labels[index], selected: index == selected)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding(.top, 6).padding(.bottom, 4)
      .frame(maxWidth: .infinity)
      .background(Color(uiColor: .secondarySystemBackground))
    }
    return type(of: chrome)._makeView(view: _GraphValue(value: chrome), inputs: inputs.child("tab-bar"))
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 7.0, *)
extension TabView where SelectionValue == Swift.Int {
  public init(@ViewBuilder content: () -> Content) {
    self.selection = nil
    self.content = content()
  }
}

/// A tab's label in the tab bar: icon above title, tinted when the tab is selected.
private struct TabBarItem: View {
  let label: ((_ViewInputs) -> _ViewOutputs)?
  let selected: Bool
  typealias Body = Never
  static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    var inputs = inputs
    inputs.foreground = [view.value.selected ? ResolvedPaint(red: 0, green: 0.478, blue: 1) : ResolvedPaint(red: 0.56, green: 0.56, blue: 0.58)]
    inputs.environment._darlingLabelStyle = _AnyLabelStyle(TabBarLabelStyle())
    return view.value.label?(inputs.child("tab-label")) ?? _ViewOutputs(text: "")
  }
}
private struct TabBarLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(spacing: 2) { configuration.icon.font(.system(size: 20)); configuration.title.font(.caption2) }
  }
}
