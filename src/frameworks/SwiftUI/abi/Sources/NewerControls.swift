// Controls and values from the iOS 18.0 SDK's interfaces that the iOS 16.5 one's generated ABI lacks.
// None is frozen, so their storage here is Darling's own. Hardware feedback, drag and drop, and
// presentation backgrounds are accepted and ignored; the first use of each is logged.
import Foundation
import CoreFoundation
import CoreTransferable

// MARK: - DatePicker

@available(iOS 13.0, macOS 10.15, watchOS 10.0, *)
@available(tvOS, unavailable)
public struct DatePickerComponents: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let hourAndMinute = DatePickerComponents(rawValue: 1 << 0)
    public static let date = DatePickerComponents(rawValue: 1 << 1)
}

/// Shows the selected date beside its label; it cannot be edited yet.
@available(iOS 13.0, macOS 10.15, watchOS 10.0, *)
@available(tvOS, unavailable)
public struct DatePicker<Label>: View where Label: View {
    public typealias Components = DatePickerComponents
    private var selection: Binding<Date>
    private var displayedComponents: Components
    private var label: Label
    fileprivate init(selection: Binding<Date>, displayedComponents: Components, label: Label) {
        self.selection = selection; self.displayedComponents = displayedComponents; self.label = label
        _abiInertValue("DatePicker")
    }
    public var body: some View {
        let formatter = DateFormatter()
        formatter.dateStyle = displayedComponents.contains(.date) ? .medium : .none
        formatter.timeStyle = displayedComponents.contains(.hourAndMinute) ? .short : .none
        return HStack {
            label
            Spacer()
            Text(verbatim: formatter.string(from: selection.wrappedValue))
        }
    }
}
@available(iOS 13.0, macOS 10.15, watchOS 10.0, *)
@available(tvOS, unavailable)
extension DatePicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, displayedComponents: DatePicker<Label>.Components = [.hourAndMinute, .date]) {
        self.init(selection: selection, displayedComponents: displayedComponents, label: Text(titleKey))
    }
}

// MARK: - Control appearance

@available(iOS 15.0, macOS 10.15, watchOS 9.0, *)
@available(tvOS, unavailable)
public enum ControlSize: CaseIterable, Hashable, Sendable {
    case mini
    case small
    case regular
    case large
    case extraLarge
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct ButtonBorderShape: Equatable, Sendable {
    private enum Kind: Equatable, Sendable { case automatic, capsule, roundedRectangle(CGFloat?), circle }
    private let kind: Kind
    public static let automatic = ButtonBorderShape(kind: .automatic)
    public static let capsule = ButtonBorderShape(kind: .capsule)
    public static let roundedRectangle = ButtonBorderShape(kind: .roundedRectangle(nil))
    public static func roundedRectangle(radius: CGFloat) -> ButtonBorderShape { ButtonBorderShape(kind: .roundedRectangle(radius)) }
    public static let circle = ButtonBorderShape(kind: .circle)
}

private struct ControlSizeKey: EnvironmentKey { static let defaultValue = ControlSize.regular }
private struct ButtonBorderShapeKey: EnvironmentKey { static let defaultValue = ButtonBorderShape.automatic }
private struct SymbolRenderingModeKey: EnvironmentKey { static let defaultValue: SymbolRenderingMode? = nil }
extension EnvironmentValues {
    public var controlSize: ControlSize {
        get { self[ControlSizeKey.self] }
        set { self[ControlSizeKey.self] = newValue }
    }
    public var _buttonBorderShape: ButtonBorderShape {
        get { self[ButtonBorderShapeKey.self] }
        set { self[ButtonBorderShapeKey.self] = newValue }
    }
    public var symbolRenderingMode: SymbolRenderingMode? {
        get { self[SymbolRenderingModeKey.self] }
        set { self[SymbolRenderingModeKey.self] = newValue }
    }
}

// MARK: - Link and ContentUnavailableView

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct Link<Label>: View where Label: View {
    @Environment(\.openURL) private var openURL
    private var destination: URL
    private var label: Label
    public init(destination: URL, @ViewBuilder label: () -> Label) {
        self.destination = destination
        self.label = label()
    }
    public var body: some View {
        Button(action: { openURL(destination) }, label: { label })
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct ContentUnavailableView<Label, Description, Actions>: View where Label: View, Description: View, Actions: View {
    private var label: Label
    private var description: Description
    private var actions: Actions
    public init(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description = { EmptyView() }, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.label = label()
        self.description = description()
        self.actions = actions()
    }
    public var body: some View {
        VStack(spacing: 8) {
            label.font(.title2)
            description.foregroundColor(.secondary)
            actions
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension ContentUnavailableView where Label == SwiftUI.Label<Text, Image>, Description == Text?, Actions == EmptyView {
    public init(_ title: LocalizedStringKey, systemImage name: String, description: Text? = nil) {
        self.label = SwiftUI.Label(title, systemImage: name)
        self.description = description
        self.actions = EmptyView()
    }
}

// MARK: - Sensory feedback

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct SensoryFeedback: Equatable, Sendable {
    private enum Kind: Equatable, Sendable {
        case success, warning, error, selection, increase, decrease, start, stop, alignment, levelChange, pathComplete
        case impact(Weight?, Flexibility?, Double)
    }
    private let kind: Kind
    public static let success = SensoryFeedback(kind: .success)
    public static let warning = SensoryFeedback(kind: .warning)
    public static let error = SensoryFeedback(kind: .error)
    public static let selection = SensoryFeedback(kind: .selection)
    public static let increase = SensoryFeedback(kind: .increase)
    public static let decrease = SensoryFeedback(kind: .decrease)
    public static let start = SensoryFeedback(kind: .start)
    public static let stop = SensoryFeedback(kind: .stop)
    public static let alignment = SensoryFeedback(kind: .alignment)
    public static let levelChange = SensoryFeedback(kind: .levelChange)
    public static let pathComplete = SensoryFeedback(kind: .pathComplete)
    public static let impact = SensoryFeedback(kind: .impact(nil, nil, 1))
    public static func impact(weight: Weight = .medium, intensity: Double = 1.0) -> SensoryFeedback {
        SensoryFeedback(kind: .impact(weight, nil, intensity))
    }
    public static func impact(flexibility: Flexibility, intensity: Double = 1.0) -> SensoryFeedback {
        SensoryFeedback(kind: .impact(nil, flexibility, intensity))
    }
    public struct Weight: Equatable, Sendable {
        private let level: Int
        public static let light = Weight(level: 0)
        public static let medium = Weight(level: 1)
        public static let heavy = Weight(level: 2)
    }
    public struct Flexibility: Equatable, Sendable {
        private let level: Int
        public static let rigid = Flexibility(level: 0)
        public static let solid = Flexibility(level: 1)
        public static let soft = Flexibility(level: 2)
    }
}

// MARK: - Modifiers Darling does not act on yet

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension View {
    public func sensoryFeedback<T>(_ feedback: SensoryFeedback, trigger: T) -> some View where T: Equatable {
        _darlingIgnoredModifier(self, "sensoryFeedback")
    }
    public func navigationDestination<D, C>(item: Binding<D?>, @ViewBuilder destination: @escaping (D) -> C) -> some View where D: Hashable, C: View {
        _darlingIgnoredModifier(self, "navigationDestination")
    }
}
@available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
extension View {
    public func presentationBackground<S>(_ style: S) -> some View where S: ShapeStyle {
        _darlingIgnoredModifier(self, "presentationBackground")
    }
}
@available(iOS 16.0, macOS 13.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension View {
    public func draggable<T>(_ payload: @autoclosure @escaping () -> T) -> some View where T: Transferable {
        _darlingIgnoredModifier(self, "draggable")
    }
    public func dropDestination<T>(for payloadType: T.Type = T.self, action: @escaping (_ items: [T], _ location: CGPoint) -> Bool, isTargeted: @escaping (Bool) -> Void = { _ in }) -> some View where T: Transferable {
        _darlingIgnoredModifier(self, "dropDestination")
    }
}
