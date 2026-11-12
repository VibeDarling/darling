// Navigation, forms and their controls, with the iOS 16.5 SDK's declarations: NavigationView and
// NavigationLink, navigationTitle, Form, Section, Toggle, Picker, Menu, DisclosureGroup,
// LabeledContent, the lazy stacks, AsyncImage and TextField.
import Foundation
import UIKit

// MARK: Navigation

/// How a navigation container's descendants push a destination onto it.
struct _NavigationPush { let push: (AnyView) -> Void }
private struct NavigationPushKey: EnvironmentKey { static let defaultValue: _NavigationPush? = nil }
extension EnvironmentValues {
  var _darlingNavigationPush: _NavigationPush? {
    get { self[NavigationPushKey.self] }
    set { self[NavigationPushKey.self] = newValue }
  }
}
extension RenderNode {
  /// The title of the first view that set one, not looking into nested navigation containers.
  var navigationTitleText: String? {
    if let title = navigationTitle { return title }
    if properties["navigation"] != nil { return nil }
    for child in children { if let title = child.navigationTitleText { return title } }
    return nil
  }
  /// The toolbar items of the views in this one, not looking into nested navigation containers.
  var navigationToolbarItems: [(placement: String, node: RenderNode)] {
    if properties["navigation"] != nil { return [] }
    return toolbarItems + children.flatMap(\.navigationToolbarItems)
  }
}

/// A bar with the top page's title (and a back button below the root) above the top page.
/// Every page is made, so that each keeps its state while another is on top.
func _darlingNavigationContainer(root: AnyView, inputs: _ViewInputs) -> _ViewOutputs {
  let stack = inputs.graph?.location(at: inputs.path.child("navigation-stack"), initial: { [AnyView]() })
  let pages = stack?.get() ?? []
  var pageInputs = inputs
  pageInputs.environment._darlingNavigationPush = _NavigationPush { view in
    guard let stack = stack else { return }
    stack.set(stack.get() + [view], Transaction())
  }
  var nodes = [AnyView._makeView(view: _GraphValue(value: root), inputs: pageInputs.child("navigation-root")).renderedNode]
  for (index, page) in pages.enumerated() {
    nodes.append(AnyView._makeView(view: _GraphValue(value: page), inputs: pageInputs.child("navigation-page").child(index)).renderedNode)
  }
  let top = nodes[nodes.count - 1]
  let title = top.navigationTitleText ?? ""
  let items = top.navigationToolbarItems
  let leading = items.filter { $0.placement == "leading" }.map(\.node)
  let trailing = items.filter { $0.placement == "trailing" }.map(\.node)
  let principal = items.first { $0.placement == "principal" }?.node
  let pop = { guard let stack = stack else { return }; stack.set(Array(stack.get().dropLast()), Transaction()) }
  let chrome = VStack(spacing: 0) {
    ZStack {
      if let principal = principal {
        _RenderedNode(node: principal)
      } else {
        Text(verbatim: title).font(.headline).lineLimit(1).padding(.horizontal, 80)
      }
      HStack(spacing: 16) {
        if !pages.isEmpty {
          Button(action: pop) { Text(verbatim: "‹ Back") }
        }
        ForEach(0..<leading.count, id: \.self) { _RenderedNode(node: leading[$0]) }
        Spacer()
        ForEach(0..<trailing.count, id: \.self) { _RenderedNode(node: trailing[$0]) }
      }
      .padding(.horizontal, 12)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 44)
    Divider()
    _RenderedNode(node: top).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
  var outputs = type(of: chrome)._makeView(view: _GraphValue(value: chrome), inputs: inputs.child("navigation-bar"))
  outputs.node.properties["navigation"] = "1"
  return outputs
}

@available(iOS, introduced: 13.0, deprecated: 100000.0, message: "use NavigationStack or NavigationSplitView instead")
@available(macOS, introduced: 10.15, deprecated: 100000.0, message: "use NavigationStack or NavigationSplitView instead")
@available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "use NavigationStack or NavigationSplitView instead")
@available(watchOS, introduced: 7.0, deprecated: 100000.0, message: "use NavigationStack or NavigationSplitView instead")
public struct NavigationView<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var content: Content
  public init(@ViewBuilder content: () -> Content) { self.content = content() }
  public typealias Body = Swift.Never
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    _darlingNavigationContainer(root: AnyView(view.value.content), inputs: inputs)
  }
}

private struct NavigationTitleModifier: ViewModifier {
  let title: (_ViewInputs) -> String
  typealias Body = Never
  static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs,
      body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
    var outputs = body(_Graph(), inputs)
    outputs.node.navigationTitle = modifier.value.title(inputs)
    outputs.node.keepTraits()
    return outputs
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension View {
  public func navigationTitle(_ title: Text) -> some View {
    modifier(NavigationTitleModifier { Text._makeView(view: _GraphValue(value: title), inputs: $0.child("navigation-title")).text })
  }
  public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View {
    navigationTitle(Text(titleKey))
  }
  @_disfavoredOverload public func navigationTitle<S>(_ title: S) -> some View where S : Swift.StringProtocol {
    navigationTitle(Text(verbatim: String(title)))
  }
}
extension View {
  @available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
  public func navigationTitle(_ title: Binding<Swift.String>) -> some View {
    modifier(NavigationTitleModifier { _ in title.wrappedValue })
  }
}

/// A row that pushes its destination onto the navigation container it is in.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct NavigationLink<Label, Destination> : View where Label : View, Destination : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var label: Label
  private var destination: Destination
  private var isActive: Binding<Bool>?
  fileprivate init(label: Label, destination: Destination, isActive: Binding<Bool>?) {
    self.label = label; self.destination = destination; self.isActive = isActive
  }
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  public init(destination: Destination, @ViewBuilder label: () -> Label) { self.init(label: label(), destination: destination, isActive: nil) }
  @available(iOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(value:label:) inside a NavigationStack or NavigationSplitView")
  public init(destination: Destination, isActive: Binding<Swift.Bool>, @ViewBuilder label: () -> Label) { self.init(label: label(), destination: destination, isActive: isActive) }
  public init<V>(destination: Destination, tag: V, selection: Binding<V?>, @ViewBuilder label: () -> Label) where V : Swift.Hashable {
    self.init(label: label(), destination: destination, isActive: Binding(get: { selection.wrappedValue == tag }, set: { selection.wrappedValue = $0 ? tag : nil }))
  }
  public typealias Body = Never
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    let push = inputs.environment._darlingNavigationPush
    // The label fills the row (a Spacer would split the space with a label that can grow too),
    // the chevron at its trailing edge.
    let row = HStack {
      value.label.frame(maxWidth: .infinity, alignment: .leading)
      Text(verbatim: "›").foregroundColor(Color(uiColor: .tertiaryLabel))
    }
    var rowInputs = inputs
    if rowInputs.foreground.isEmpty { rowInputs.foreground = [Color.primary.resolve(inputs)] }
    let label = type(of: row)._makeView(view: _GraphValue(value: row), inputs: rowInputs.child("label"))
    return makeButton(label: label, action: {
      value.isActive?.wrappedValue = true
      push?.push(AnyView(value.destination))
    }, inputs: inputs)
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension NavigationLink where Label == Text {
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  public init(_ titleKey: LocalizedStringKey, destination: Destination) { self.init(label: Text(titleKey), destination: destination, isActive: nil) }
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  @_disfavoredOverload public init<S>(_ title: S, destination: Destination) where S : Swift.StringProtocol { self.init(label: Text(verbatim: String(title)), destination: destination, isActive: nil) }
  public init(_ titleKey: LocalizedStringKey, destination: Destination, isActive: Binding<Swift.Bool>) { self.init(label: Text(titleKey), destination: destination, isActive: isActive) }
  @_disfavoredOverload public init<S>(_ title: S, destination: Destination, isActive: Binding<Swift.Bool>) where S : Swift.StringProtocol { self.init(label: Text(verbatim: String(title)), destination: destination, isActive: isActive) }
  public init<V>(_ titleKey: LocalizedStringKey, destination: Destination, tag: V, selection: Binding<V?>) where V : Swift.Hashable {
    self.init(destination: destination, tag: tag, selection: selection) { Text(titleKey) }
  }
  @_disfavoredOverload public init<S, V>(_ title: S, destination: Destination, tag: V, selection: Binding<V?>) where S : Swift.StringProtocol, V : Swift.Hashable {
    self.init(destination: destination, tag: tag, selection: selection) { Text(verbatim: String(title)) }
  }
}

// MARK: Form and Section

/// Sections of rows, scrolling, on the grouped background.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Form<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var content: Content
  public init(@ViewBuilder content: () -> Content) { self.content = content() }
  @preconcurrency @MainActor public var body: some View {
    ScrollView { VStack(alignment: .leading, spacing: 0) { content }.padding(.bottom, 16) }
      .background(Color(uiColor: .systemGroupedBackground))
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Form where Content == FormStyleConfiguration.Content {
  public init(_ configuration: FormStyleConfiguration) { _abiUnimplemented("Form: public init(_ configuration: FormStyleConfiguration)") }
}

/// The header, the content's rows (separated, on a card) and the footer.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Section<Parent, Content, Footer> {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  fileprivate var header: Parent
  fileprivate var content: Content
  fileprivate var footer: Footer
  fileprivate init(header: Parent, content: Content, footer: Footer) { self.header = header; self.content = content; self.footer = footer }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section : View where Parent : View, Content : View, Footer : View {
  public typealias Body = Swift.Never
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public static func _viewListCount(inputs: _ViewListCountInputs) -> Swift.Int? { nil }
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    let rows = Content._makeView(view: _GraphValue(value: value.content), inputs: inputs.child("section-content")).renderedNode.list
    var captionInputs = inputs
    captionInputs.foreground = [Color.secondary.resolve(inputs)]
    let header = Parent._makeView(view: _GraphValue(value: value.header), inputs: captionInputs.child("section-header")).renderedNode
    let footer = Footer._makeView(view: _GraphValue(value: value.footer), inputs: captionInputs.child("section-footer")).renderedNode
    let section = VStack(alignment: .leading, spacing: 0) {
      if header.kind != "empty" {
        _RenderedNode(node: header).font(.footnote).textCase(.uppercase)
          .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 7)
      } else {
        Spacer().frame(height: 22)
      }
      VStack(alignment: .leading, spacing: 0) {
        ForEach(0..<rows.count, id: \.self) { index in
          _RenderedNode(node: rows[index]).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(.horizontal, 16)
          if index < rows.count - 1 { Divider().padding(.leading, 16) }
        }
      }
      .background(Color(uiColor: .secondarySystemGroupedBackground))
      if footer.kind != "empty" {
        _RenderedNode(node: footer).font(.footnote).padding(.horizontal, 20).padding(.top, 7)
      }
    }
    return type(of: section)._makeView(view: _GraphValue(value: section), inputs: inputs.child("section"))
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent == EmptyView, Content : View, Footer == EmptyView {
  public init(@ViewBuilder content: () -> Content) { self.init(header: EmptyView(), content: content(), footer: EmptyView()) }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Section where Parent == Text, Content : View, Footer == EmptyView {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.init(header: Text(titleKey), content: content(), footer: EmptyView()) }
  @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S : Swift.StringProtocol { self.init(header: Text(verbatim: String(title)), content: content(), footer: EmptyView()) }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent : View, Content : View, Footer : View {
  @available(iOS, deprecated: 100000.0, renamed: "Section(content:header:footer:)")
  public init(header: Parent, footer: Footer, @ViewBuilder content: () -> Content) { self.init(header: header, content: content(), footer: footer) }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent == EmptyView, Content : View, Footer : View {
  @available(iOS, deprecated: 100000.0, renamed: "Section(content:footer:)")
  public init(footer: Footer, @ViewBuilder content: () -> Content) { self.init(header: EmptyView(), content: content(), footer: footer) }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent : View, Content : View, Footer == EmptyView {
  @available(iOS, deprecated: 100000.0, renamed: "Section(content:header:)")
  public init(header: Parent, @ViewBuilder content: () -> Content) { self.init(header: header, content: content(), footer: EmptyView()) }
}

// MARK: Controls

/// The label, then a UISwitch.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Toggle<Label> : View where Label : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var isOn: Binding<Bool>
  private var label: Label
  fileprivate init(isOn: Binding<Bool>, label: Label) { self.isOn = isOn; self.label = label }
  public init(isOn: Binding<Swift.Bool>, @ViewBuilder label: () -> Label) { self.init(isOn: isOn, label: label()) }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init<C>(sources: C, isOn: Swift.KeyPath<C.Element, Binding<Swift.Bool>>, @ViewBuilder label: () -> Label) where C : Swift.RandomAccessCollection {
    let bindings = sources.map { $0[keyPath: isOn] }
    self.init(isOn: Binding(get: { !bindings.isEmpty && bindings.allSatisfy(\.wrappedValue) },
                            set: { value in bindings.forEach { $0.wrappedValue = value } }), label: label())
  }
  @preconcurrency @MainActor public var body: some View {
    HStack { label; Spacer(); SwitchControl(isOn: isOn) }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Toggle where Label == ToggleStyleConfiguration.Label {
  public init(_ configuration: ToggleStyleConfiguration) { _abiUnimplemented("Toggle: public init(_ configuration: ToggleStyleConfiguration)") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Toggle where Label == Text {
  public init(_ titleKey: LocalizedStringKey, isOn: Binding<Swift.Bool>) { self.init(isOn: isOn, label: Text(titleKey)) }
  @_disfavoredOverload public init<S>(_ title: S, isOn: Binding<Swift.Bool>) where S : Swift.StringProtocol { self.init(isOn: isOn, label: Text(verbatim: String(title))) }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init<C>(_ titleKey: LocalizedStringKey, sources: C, isOn: Swift.KeyPath<C.Element, Binding<Swift.Bool>>) where C : Swift.RandomAccessCollection {
    self.init(sources: sources, isOn: isOn) { Text(titleKey) }
  }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  @_disfavoredOverload public init<S, C>(_ title: S, sources: C, isOn: Swift.KeyPath<C.Element, Binding<Swift.Bool>>) where S : Swift.StringProtocol, C : Swift.RandomAccessCollection {
    self.init(sources: sources, isOn: isOn) { Text(verbatim: String(title)) }
  }
}
private struct SwitchControl: UIViewRepresentable {
  let isOn: Binding<Bool>
  final class Coordinator: NSObject {
    var control: SwitchControl
    init(_ control: SwitchControl) { self.control = control }
    @objc func valueChanged(_ sender: UISwitch) {
      if control.isOn.wrappedValue != sender.isOn { control.isOn.wrappedValue = sender.isOn }
    }
  }
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> UISwitch {
    let view = UISwitch()
    view.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
    return view
  }
  func updateUIView(_ uiView: UISwitch, context: Context) {
    context.coordinator.control = self
    if uiView.isOn != isOn.wrappedValue { uiView.isOn = isOn.wrappedValue }
  }
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISwitch, context: Context) -> CGSize? { CGSize(width: 51, height: 31) }
}

/// Offers choices as an action sheet, Darling's stand-in for UIKit menus.
func _darlingPresentChoices(title: String?, _ choices: [(title: String, destructive: Bool, action: () -> Void)]) {
  guard let controller = darlingHostViewController else { return }
  let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
  for choice in choices {
    sheet.addAction(UIAlertAction(title: choice.title, style: choice.destructive ? .destructive : .default) { _ in choice.action() })
  }
  sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
  var presenter = controller
  while let presented = presenter.presentedViewController { presenter = presented }
  presenter.present(sheet, animated: true)
}

private struct PickerStyleKey: EnvironmentKey { static let defaultValue = "menu" }
extension EnvironmentValues {
  var _darlingPickerStyle: String {
    get { self[PickerStyleKey.self] }
    set { self[PickerStyleKey.self] = newValue }
  }
}
extension View {
  public func pickerStyle<S>(_ style: S) -> some View where S : PickerStyle {
    let name: String
    switch style {
    case is SegmentedPickerStyle: name = "segmented"
    case is InlinePickerStyle, is WheelPickerStyle: name = "inline"
    default: name = "menu"
    }
    return environment(\._darlingPickerStyle, name)
  }
}

/// The options are the content's views, matched to the selection by their tags. The menu style
/// (the default) shows the label and the selected option, which offers the others when tapped;
/// the segmented style shows a button per option, the inline style a row per option.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Picker<Label, SelectionValue, Content> : View where Label : View, SelectionValue : Swift.Hashable, Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var selection: Binding<SelectionValue>
  private var label: Label
  private var content: Content
  fileprivate init(selection: Binding<SelectionValue>, label: Label, content: Content) {
    self.selection = selection; self.label = label; self.content = content
  }
  public typealias Body = Never
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    let options = Content._makeView(view: _GraphValue(value: value.content), inputs: inputs.child("picker-options")).renderedNode.list
    func tags(_ index: Int) -> [AnyHashable] { options[index].traitCarriers.flatMap(\.tags) }
    let current = AnyHashable(value.selection.wrappedValue)
    let selected = options.indices.first { tags($0).contains(current) }
    func select(_ index: Int) {
      for tag in tags(index) {
        if let tag = tag.base as? SelectionValue { value.selection.wrappedValue = tag; return }
      }
    }
    let titles = options.map(\.plainText)
    let label = Label._makeView(view: _GraphValue(value: value.label), inputs: inputs.child("picker-label")).renderedNode
    let picker: AnyView
    switch inputs.environment._darlingPickerStyle {
    case "segmented":
      picker = AnyView(HStack(spacing: 0) {
        ForEach(0..<options.count, id: \.self) { index in
          Button { select(index) } label: {
            Text(verbatim: titles[index]).font(.subheadline).lineLimit(1)
              .foregroundColor(index == selected ? .white : .primary)
              .frame(maxWidth: .infinity).padding(.vertical, 6)
              .background(index == selected ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
          }
        }
      })
    case "inline":
      picker = AnyView(VStack(alignment: .leading, spacing: 0) {
        ForEach(0..<options.count, id: \.self) { index in
          Button { select(index) } label: {
            HStack {
              _RenderedNode(node: options[index]).foregroundColor(.primary)
              Spacer()
              if index == selected { Text(verbatim: "✓") }
            }
            .frame(minHeight: 44)
          }
        }
      })
    default:
      let title = label.plainText
      picker = AnyView(HStack {
        _RenderedNode(node: label)
        Spacer()
        Button {
          _darlingPresentChoices(title: title.isEmpty ? nil : title,
                                 titles.indices.map { index in (titles[index], false, { select(index) }) })
        } label: {
          Text(verbatim: (selected.map { titles[$0] } ?? "") + " ⌄")
        }
      })
    }
    return AnyView._makeView(view: _GraphValue(value: picker), inputs: inputs.child("picker"))
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Picker {
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init<C>(sources: C, selection: Swift.KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) where C : Swift.RandomAccessCollection {
    let bindings = sources.map { $0[keyPath: selection] }
    self.init(selection: Binding(get: { bindings[bindings.startIndex].wrappedValue }, set: { value in bindings.forEach { $0.wrappedValue = value } }),
              label: label(), content: content())
  }
  @available(iOS, deprecated: 100000.0, renamed: "Picker(selection:content:label:)")
  public init(selection: Binding<SelectionValue>, label: Label, @ViewBuilder content: () -> Content) { self.init(selection: selection, label: label, content: content()) }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Picker where Label == Text {
  public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
    self.init(selection: selection, label: Text(titleKey), content: content())
  }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init<C>(_ titleKey: LocalizedStringKey, sources: C, selection: Swift.KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content) where C : Swift.RandomAccessCollection {
    self.init(sources: sources, selection: selection, content: content) { Text(titleKey) }
  }
  @_disfavoredOverload public init<S>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) where S : Swift.StringProtocol {
    self.init(selection: selection, label: Text(verbatim: String(title)), content: content())
  }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  @_disfavoredOverload public init<C, S>(_ title: S, sources: C, selection: Swift.KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content) where C : Swift.RandomAccessCollection, S : Swift.StringProtocol {
    self.init(sources: sources, selection: selection, content: content) { Text(verbatim: String(title)) }
  }
}

extension RenderNode {
  /// The buttons in a node, depth first, as (title, destructive, identity).
  var buttons: [(title: String, destructive: Bool, identity: String)] {
    if kind == "button", let identity = properties["action"] {
      return properties["enabled"] == "false" ? [] : [(plainText, false, identity)]
    }
    return children.flatMap(\.buttons)
  }
}

/// Its label as a button that offers the content's buttons as choices.
@available(iOS 14.0, macOS 11.0, tvOS 17.0, *)
public struct Menu<Label, Content> : View where Label : View, Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var label: Label
  private var content: Content
  private var primaryAction: (() -> Void)?
  fileprivate init(label: Label, content: Content, primaryAction: (() -> Void)?) {
    self.label = label; self.content = content; self.primaryAction = primaryAction
  }
  public typealias Body = Never
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    // Made now, so that the buttons' actions are registered for this rendering.
    let items = Content._makeView(view: _GraphValue(value: value.content), inputs: inputs.child("menu-content")).renderedNode.buttons
    var labelInputs = inputs
    if labelInputs.foreground.isEmpty { labelInputs.foreground = [Color.accentColor.resolve(inputs)] }
    let label = Label._makeView(view: _GraphValue(value: value.label), inputs: labelInputs.child("label"))
    return makeButton(label: label, action: {
      if let primary = value.primaryAction { primary(); return }
      _darlingPresentChoices(title: nil, items.map { item in (item.title, item.destructive, {
        _ = item.identity.withCString { darlingActivateButton($0) }
      }) })
    }, inputs: inputs)
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 17.0, *)
extension Menu {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.init(label: label(), content: content(), primaryAction: nil) }
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) where Label == Text { self.init(label: Text(titleKey), content: content(), primaryAction: nil) }
  @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content) where Label == Text, S : Swift.StringProtocol { self.init(label: Text(verbatim: String(title)), content: content(), primaryAction: nil) }
}
@available(iOS 15.0, macOS 12.0, *)
extension Menu {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, primaryAction: @escaping () -> Swift.Void) { self.init(label: label(), content: content(), primaryAction: primaryAction) }
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Swift.Void) where Label == Text { self.init(label: Text(titleKey), content: content(), primaryAction: primaryAction) }
  @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Swift.Void) where Label == Text, S : Swift.StringProtocol { self.init(label: Text(verbatim: String(title)), content: content(), primaryAction: primaryAction) }
}
@available(iOS 14.0, macOS 11.0, tvOS 17.0, *)
extension Menu where Label == MenuStyleConfiguration.Label, Content == MenuStyleConfiguration.Content {
  public init(_ configuration: MenuStyleConfiguration) { _abiUnimplemented("Menu: public init(_ configuration: MenuStyleConfiguration)") }
}

/// The label with a chevron, which shows or hides the content below it.
@available(iOS 14.0, macOS 11.0, *)
public struct DisclosureGroup<Label, Content> : View where Label : View, Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var label: Label
  private var content: () -> Content
  private var isExpanded: Binding<Bool>?
  fileprivate init(label: Label, content: @escaping () -> Content, isExpanded: Binding<Bool>?) {
    self.label = label; self.content = content; self.isExpanded = isExpanded
  }
  public init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) { self.init(label: label(), content: content, isExpanded: nil) }
  public init(isExpanded: Binding<Swift.Bool>, @ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) { self.init(label: label(), content: content, isExpanded: isExpanded) }
  public typealias Body = Never
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    let own = inputs.graph?.location(at: inputs.path.child("disclosure-expanded"), initial: { false })
    let expanded = value.isExpanded ?? own.map { location in Binding(get: { location.get() }, set: { location.set($0, Transaction()) }) } ?? .constant(false)
    let group = VStack(alignment: .leading, spacing: 0) {
      Button { expanded.wrappedValue.toggle() } label: {
        HStack {
          value.label.foregroundColor(.primary)
          Spacer()
          Text(verbatim: expanded.wrappedValue ? "⌄" : "›")
        }
        .frame(minHeight: 44)
      }
      if expanded.wrappedValue { value.content().padding(.leading, 16) }
    }
    return type(of: group)._makeView(view: _GraphValue(value: group), inputs: inputs.child("disclosure"))
  }
}
@available(iOS 14.0, macOS 11.0, *)
extension DisclosureGroup where Label == Text {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) { self.init(label: Text(titleKey), content: content, isExpanded: nil) }
  public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Swift.Bool>, @ViewBuilder content: @escaping () -> Content) { self.init(label: Text(titleKey), content: content, isExpanded: isExpanded) }
  @_disfavoredOverload public init<S>(_ label: S, @ViewBuilder content: @escaping () -> Content) where S : Swift.StringProtocol { self.init(label: Text(verbatim: String(label)), content: content, isExpanded: nil) }
  @_disfavoredOverload public init<S>(_ label: S, isExpanded: Binding<Swift.Bool>, @ViewBuilder content: @escaping () -> Content) where S : Swift.StringProtocol { self.init(label: Text(verbatim: String(label)), content: content, isExpanded: isExpanded) }
}

/// The label, then the content in the secondary color at the trailing edge.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct LabeledContent<Label, Content> {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  fileprivate var label: Label
  fileprivate var content: Content
  fileprivate init(label: Label, content: Content) { self.label = label; self.content = content }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension LabeledContent : View where Label : View, Content : View {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.init(label: label(), content: content()) }
  @preconcurrency @MainActor public var body: some View {
    HStack { label; Spacer(); content.foregroundColor(.secondary) }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension LabeledContent where Label == Text, Content : View {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.init(label: Text(titleKey), content: content()) }
  @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S : Swift.StringProtocol { self.init(label: Text(verbatim: String(title)), content: content()) }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension LabeledContent where Label == Text, Content == Text {
  public init<S>(_ titleKey: LocalizedStringKey, value: S) where S : Swift.StringProtocol { self.init(label: Text(titleKey), content: Text(verbatim: String(value))) }
  @_disfavoredOverload public init<S1, S2>(_ title: S1, value: S2) where S1 : Swift.StringProtocol, S2 : Swift.StringProtocol { self.init(label: Text(verbatim: String(title)), content: Text(verbatim: String(value))) }
  public init<F>(_ titleKey: LocalizedStringKey, value: F.FormatInput, format: F) where F : Foundation.FormatStyle, F.FormatInput : Swift.Equatable, F.FormatOutput == Swift.String {
    self.init(label: Text(titleKey), content: Text(verbatim: format.format(value)))
  }
  public init<S, F>(_ title: S, value: F.FormatInput, format: F) where S : Swift.StringProtocol, F : Foundation.FormatStyle, F.FormatInput : Swift.Equatable, F.FormatOutput == Swift.String {
    self.init(label: Text(verbatim: String(title)), content: Text(verbatim: format.format(value)))
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension LabeledContent where Label == LabeledContentStyleConfiguration.Label, Content == LabeledContentStyleConfiguration.Content {
  public init(_ configuration: LabeledContentStyleConfiguration) { _abiUnimplemented("LabeledContent: public init(_ configuration: LabeledContentStyleConfiguration)") }
}

// MARK: Lazy stacks

/// A VStack: Darling makes every view at once.
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LazyVStack<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var alignment: HorizontalAlignment
  private var spacing: CGFloat?
  private var content: Content
  public init(alignment: HorizontalAlignment = .center, spacing: CoreFoundation.CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {
    self.alignment = alignment; self.spacing = spacing; self.content = content()
  }
  public typealias Body = Swift.Never
  public static func _makeView(view: _GraphValue<LazyVStack<Content>>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    let stack = VStack(alignment: value.alignment, spacing: value.spacing) { value.content }
    return type(of: stack)._makeView(view: _GraphValue(value: stack), inputs: inputs)
  }
}
/// An HStack: Darling makes every view at once.
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LazyHStack<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var alignment: VerticalAlignment
  private var spacing: CGFloat?
  private var content: Content
  public init(alignment: VerticalAlignment = .center, spacing: CoreFoundation.CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {
    self.alignment = alignment; self.spacing = spacing; self.content = content()
  }
  public typealias Body = Swift.Never
  public static func _makeView(view: _GraphValue<LazyHStack<Content>>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    let stack = HStack(alignment: value.alignment, spacing: value.spacing) { value.content }
    return type(of: stack)._makeView(view: _GraphValue(value: stack), inputs: inputs)
  }
}

// MARK: AsyncImage

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public enum AsyncImagePhase {
  case empty
  case success(Image)
  case failure(any Swift.Error)
  public var image: Image? {
    if case .success(let image) = self { return image }
    return nil
  }
  public var error: (any Swift.Error)? {
    if case .failure(let error) = self { return error }
    return nil
  }
}

/// One image load, kept in the view's state.
private final class AsyncImageLoad {
  var url: URL?
  var phase = AsyncImagePhase.empty
  var task: URLSessionDataTask?
  deinit { task?.cancel() }
}
private struct AsyncImageError: LocalizedError {
  var errorDescription: String? { "The image could not be decoded." }
}

/// Loads its URL with URLSession and shows the content for each phase of the load.
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct AsyncImage<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var url: URL?
  private var scale: CGFloat
  private var content: (AsyncImagePhase) -> Content
  public init(url: Foundation.URL?, scale: CoreFoundation.CGFloat = 1) where Content == Image {
    self.url = url; self.scale = scale
    content = { $0.image ?? Image(uiImage: UIImage()) }
  }
  public init(url: Foundation.URL?, scale: CoreFoundation.CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
    self.url = url; self.scale = scale; self.content = content
  }
  public typealias Body = Never
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    let location = inputs.graph?.location(at: inputs.path.child("async-image"), initial: { AsyncImageLoad() })
    if let location = location {
      let load = location.get()
      if load.url != value.url {
        load.task?.cancel()
        load.url = value.url
        load.phase = .empty
        load.task = nil
        if let url = value.url {
          let scale = value.scale
          let task = URLSession.shared.dataTask(with: url) { [weak load] data, _, error in
            DispatchQueue.main.async {
              guard let load = load, load.url == url else { return }
              if let data = data, let image = UIImage(data: data, scale: scale) {
                load.phase = .success(Image(uiImage: image))
              } else {
                load.phase = .failure(error ?? AsyncImageError())
              }
              location.set(load, Transaction())
            }
          }
          load.task = task
          task.resume()
        }
      }
      return Content._makeView(view: _GraphValue(value: value.content(load.phase)), inputs: inputs.child("async-image-content"))
    }
    return Content._makeView(view: _GraphValue(value: value.content(.empty)), inputs: inputs.child("async-image-content"))
  }
}

// MARK: TextField

/// A UITextField for the text, with the prompt (else the label) as its placeholder.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct TextField<Label> : View where Label : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var text: Binding<String>
  private var prompt: Text?
  private var label: Label
  private var onEditingChanged: (Bool) -> Void
  private var onCommit: () -> Void
  fileprivate init(text: Binding<String>, prompt: Text?, label: Label,
                   onEditingChanged: @escaping (Bool) -> Void = { _ in }, onCommit: @escaping () -> Void = {}) {
    self.text = text; self.prompt = prompt; self.label = label
    self.onEditingChanged = onEditingChanged; self.onCommit = onCommit
  }
  public typealias Body = Never
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    let value = view.value
    let placeholder = value.prompt.map { Text._makeView(view: _GraphValue(value: $0), inputs: inputs.child("prompt")).text }
      ?? Label._makeView(view: _GraphValue(value: value.label), inputs: inputs.child("label")).text
    let field = _DarlingTextField(text: value.text, placeholder: placeholder, secure: false,
                                  onEditingChanged: value.onEditingChanged, onCommit: value.onCommit)
    return _DarlingTextField._makeView(view: _GraphValue(value: field), inputs: inputs)
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension TextField where Label == Text {
  public init(_ titleKey: LocalizedStringKey, text: Binding<Swift.String>, axis: Axis) { self.init(text: text, prompt: nil, label: Text(titleKey)) }
  public init(_ titleKey: LocalizedStringKey, text: Binding<Swift.String>, prompt: Text?, axis: Axis) { self.init(text: text, prompt: prompt, label: Text(titleKey)) }
  @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, axis: Axis) where S : Swift.StringProtocol { self.init(text: text, prompt: nil, label: Text(verbatim: String(title))) }
  @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, prompt: Text?, axis: Axis) where S : Swift.StringProtocol { self.init(text: text, prompt: prompt, label: Text(verbatim: String(title))) }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension TextField {
  public init(text: Binding<Swift.String>, prompt: Text? = nil, axis: Axis, @ViewBuilder label: () -> Label) { self.init(text: text, prompt: prompt, label: label()) }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TextField where Label == Text {
  public init(_ titleKey: LocalizedStringKey, text: Binding<Swift.String>, prompt: Text?) { self.init(text: text, prompt: prompt, label: Text(titleKey)) }
  @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, prompt: Text?) where S : Swift.StringProtocol { self.init(text: text, prompt: prompt, label: Text(verbatim: String(title))) }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TextField {
  public init(text: Binding<Swift.String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) { self.init(text: text, prompt: prompt, label: label()) }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension TextField where Label == Text {
  public init(_ titleKey: LocalizedStringKey, text: Binding<Swift.String>, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void, onCommit: @escaping () -> Swift.Void) {
    self.init(text: text, prompt: nil, label: Text(titleKey), onEditingChanged: onEditingChanged, onCommit: onCommit)
  }
  @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void, onCommit: @escaping () -> Swift.Void) where S : Swift.StringProtocol {
    self.init(text: text, prompt: nil, label: Text(verbatim: String(title)), onEditingChanged: onEditingChanged, onCommit: onCommit)
  }
}

/// A UITextField bound to a string, for TextField and SecureField.
struct _DarlingTextField: UIViewRepresentable {
  let text: Binding<String>
  let placeholder: String
  let secure: Bool
  var onEditingChanged: (Bool) -> Void = { _ in }
  let onCommit: () -> Void

  final class Coordinator: NSObject, UITextFieldDelegate {
    var field: _DarlingTextField
    init(_ field: _DarlingTextField) { self.field = field }
    @objc func editingChanged(_ sender: UITextField) {
      let value = sender.text ?? ""
      if field.text.wrappedValue != value { field.text.wrappedValue = value }
    }
    func textFieldDidBeginEditing(_ textField: UITextField) { field.onEditingChanged(true) }
    func textFieldDidEndEditing(_ textField: UITextField) { field.onEditingChanged(false) }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
      field.onCommit()
      textField.resignFirstResponder()
      return true
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> UITextField {
    let view = UITextField()
    view.isSecureTextEntry = secure
    view.borderStyle = .none
    if secure {
      view.autocapitalizationType = .none
      view.autocorrectionType = .no
    }
    view.delegate = context.coordinator
    view.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
    return view
  }
  func updateUIView(_ uiView: UITextField, context: Context) {
    context.coordinator.field = self
    if uiView.text != text.wrappedValue { uiView.text = text.wrappedValue }
    if uiView.placeholder != placeholder { uiView.placeholder = placeholder }
  }
  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
    CGSize(width: proposal.width ?? 200, height: 34)
  }
}
