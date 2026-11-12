// Edit mode, EditButton, SecureField, ColorPicker and LazyHGrid, with the SDK interface's
// declarations, and the environment values and modifiers that go with them.
import CoreFoundation
import UIKit

// MARK: Edit mode

@available(iOS 13.0, tvOS 13.0, *)
public enum EditMode: Hashable {
    case inactive
    case transient
    case active
    public var isEditing: Bool { self != .inactive }
}

/// Nil unless a view provides one, as in SwiftUI outside a navigation container.
private struct EditModeKey: EnvironmentKey { static let defaultValue: Binding<EditMode>? = nil }
extension EnvironmentValues {
    @available(iOS 13.0, tvOS 13.0, *)
    public var editMode: Binding<EditMode>? {
        get { self[EditModeKey.self] }
        set { self[EditModeKey.self] = newValue }
    }
}

/// Toggles the environment's edit mode between active and inactive.
@available(iOS 13.0, *)
public struct EditButton: View {
    @Environment(\.editMode) private var editMode
    public init() {}
    public var body: some View {
        Button(editMode?.wrappedValue.isEditing == true ? "Done" : "Edit") {
            guard let editMode = editMode else { return }
            editMode.wrappedValue = editMode.wrappedValue.isEditing ? .inactive : .active
        }
    }
}

// MARK: SecureField

/// A text field whose entry is hidden: a UITextField with secure text entry.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct SecureField<Label: View>: View {
    private let text: Binding<String>
    private let prompt: Text?
    private let label: Label
    private let onCommit: () -> Void
    fileprivate init(text: Binding<String>, prompt: Text?, label: Label, onCommit: @escaping () -> Void) {
        self.text = text
        self.prompt = prompt
        self.label = label
        self.onCommit = onCommit
    }
    public var body: some View {
        SecureFieldBody(text: text, prompt: prompt, label: label, onCommit: onCommit)
    }
}

extension SecureField where Label == Text {
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {
        self.init(text: text, prompt: prompt, label: Text(titleKey), onCommit: {})
    }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text?) {
        self.init(text: text, prompt: prompt, label: Text(verbatim: String(title)), onCommit: {})
    }
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, onCommit: @escaping () -> Void) {
        self.init(text: text, prompt: nil, label: Text(titleKey), onCommit: onCommit)
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>, onCommit: @escaping () -> Void) {
        self.init(text: text, prompt: nil, label: Text(verbatim: String(title)), onCommit: onCommit)
    }
    @_alwaysEmitIntoClient public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {
        self.init(titleKey, text: text, onCommit: {})
    }
    @_alwaysEmitIntoClient @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>) {
        self.init(title, text: text, onCommit: {})
    }
}

extension SecureField {
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public init(text: Binding<String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) {
        self.init(text: text, prompt: prompt, label: label(), onCommit: {})
    }
}

/// Resolves the placeholder (the prompt, else the label) to plain text for the UIKit field.
private struct SecureFieldBody<Label: View>: View {
    let text: Binding<String>
    let prompt: Text?
    let label: Label
    let onCommit: () -> Void
    typealias Body = Never
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let value = view.value
        let placeholder = value.prompt.map { Text._makeView(view: _GraphValue(value: $0), inputs: inputs.child("prompt")).text }
            ?? Label._makeView(view: _GraphValue(value: value.label), inputs: inputs.child("label")).text
        let field = _DarlingTextField(text: value.text, placeholder: placeholder, secure: true, onCommit: value.onCommit)
        return _DarlingTextField._makeView(view: _GraphValue(value: field), inputs: inputs)
    }
}

// MARK: ColorPicker

/// The label, then a swatch of the selected color. Darling has no color panel to pick from.
@available(iOS 14.0, macOS 11.0, *)
public struct ColorPicker<Label: View>: View {
    private let selection: Binding<Color>
    private let supportsOpacity: Bool
    private let label: Label
    public init(selection: Binding<Color>, supportsOpacity: Bool = true, @ViewBuilder label: () -> Label) {
        self.selection = selection
        self.supportsOpacity = supportsOpacity
        self.label = label()
    }
    public var body: some View {
        HStack {
            label
            Spacer()
            Circle().fill(selection.wrappedValue).frame(width: 28, height: 28)
        }
    }
}

extension ColorPicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Color>, supportsOpacity: Bool = true) {
        self.init(selection: selection, supportsOpacity: supportsOpacity) { Text(titleKey) }
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, selection: Binding<Color>, supportsOpacity: Bool = true) {
        self.init(selection: selection, supportsOpacity: supportsOpacity) { Text(verbatim: String(title)) }
    }
}

// MARK: LazyHGrid

/// Lays its views out in columns of `rows.count`, all at once rather than lazily.
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LazyHGrid<Content: View>: View {
    private let rows: [GridItem]
    private let alignment: VerticalAlignment
    private let spacing: CGFloat?
    private let content: Content
    public init(rows: [GridItem], alignment: VerticalAlignment = .center, spacing: CGFloat? = nil,
                pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {
        self.rows = rows
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let grid = view.value
        var childInputs = inputs.child("LazyHGrid")
        childInputs.stackAxis = "vertical"
        let views = Content._makeView(view: _GraphValue(value: grid.content), inputs: childInputs).renderedNode.list
        let perColumn = max(grid.rows.count, 1)
        let spacing = Double(grid.spacing ?? 8)
        let columns = stride(from: 0, to: views.count, by: perColumn).map { start in
            RenderNode(kind: "vstack", children: Array(views[start..<min(start + perColumn, views.count)]),
                       spacing: spacing, horizontal: 1, vertical: 1)
        }
        return _ViewOutputs(node: RenderNode(kind: "hstack", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("lazy-hgrid")) ?? "",
                                             children: columns, spacing: spacing, horizontal: 1, vertical: Int(grid.alignment.key.bits)))
    }
}

// MARK: Header prominence, keyboard dismissal, content transitions

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public enum Prominence: Hashable {
    case standard
    case increased
}

private struct HeaderProminenceKey: EnvironmentKey { static let defaultValue = Prominence.standard }
extension EnvironmentValues {
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public var headerProminence: Prominence {
        get { self[HeaderProminenceKey.self] }
        set { self[HeaderProminenceKey.self] = newValue }
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct ScrollDismissesKeyboardMode {
    private let value: UInt8
    public static var automatic: Self { Self(value: 0) }
    public static var immediately: Self { Self(value: 1) }
    public static var interactively: Self { Self(value: 2) }
    public static var never: Self { Self(value: 3) }
}

private struct ScrollDismissesKeyboardModeKey: EnvironmentKey { static let defaultValue = ScrollDismissesKeyboardMode.automatic }
extension EnvironmentValues {
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public var scrollDismissesKeyboardMode: ScrollDismissesKeyboardMode {
        get { self[ScrollDismissesKeyboardModeKey.self] }
        set { self[ScrollDismissesKeyboardModeKey.self] = newValue }
    }
}

/// How a view's content changes between updates. Darling's SwiftUI does not animate, so every
/// transition replaces the content at once.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct ContentTransition: Equatable {
    private let kind: UInt8
    private let countsDown: Bool
    private init(kind: UInt8, countsDown: Bool = false) { self.kind = kind; self.countsDown = countsDown }
    public static var identity: Self { Self(kind: 0) }
    public static var opacity: Self { Self(kind: 1) }
    public static var interpolate: Self { Self(kind: 2) }
    public static func numericText(countsDown: Bool = false) -> Self { Self(kind: 3, countsDown: countsDown) }
}

private struct ContentTransitionKey: EnvironmentKey { static let defaultValue = ContentTransition.identity }
private struct ContentTransitionAddsDrawingGroupKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public var contentTransition: ContentTransition {
        get { self[ContentTransitionKey.self] }
        set { self[ContentTransitionKey.self] = newValue }
    }
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public var contentTransitionAddsDrawingGroup: Bool {
        get { self[ContentTransitionAddsDrawingGroupKey.self] }
        set { self[ContentTransitionAddsDrawingGroupKey.self] = newValue }
    }
}

extension View {
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @_alwaysEmitIntoClient public func contentTransition(_ transition: ContentTransition) -> some View {
        environment(\.contentTransition, transition)
    }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public func headerProminence(_ prominence: Prominence) -> some View {
        environment(\.headerProminence, prominence)
    }
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func scrollDismissesKeyboard(_ mode: ScrollDismissesKeyboardMode) -> some View {
        environment(\.scrollDismissesKeyboardMode, mode)
    }
}

// MARK: Modifiers Darling shows the content without

extension View {
    /// There is no long press menu: the menu items are never shown.
    @available(iOS 13.0, macOS 10.15, tvOS 14.0, *)
    public func contextMenu<MenuItems: View>(@ViewBuilder menuItems: () -> MenuItems) -> some View {
        _darlingIgnoredModifier(self, "contextMenu")
    }
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func searchScopes<V: Hashable, S: View>(_ scope: Binding<V>, @ViewBuilder scopes: () -> S) -> some View {
        _darlingIgnoredModifier(self, "searchScopes")
    }
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func toolbarTitleMenu<C: View>(@ViewBuilder content: () -> C) -> some View {
        _darlingIgnoredModifier(self, "toolbarTitleMenu")
    }
    @available(iOS 13.0, tvOS 13.0, *)
    public func autocapitalization(_ style: UITextAutocapitalizationType) -> some View {
        _darlingIgnoredModifier(self, "autocapitalization")
    }
}
