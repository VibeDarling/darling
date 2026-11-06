// Text field styles, text selection and formatted Text, from the iOS 18.0 SDK's interfaces. Darling's
// TextField and Text do not act on the styles or on selection yet.
import Foundation

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol TextFieldStyle {
    associatedtype _Body: View
    @ViewBuilder func _body(configuration: TextField<Self._Label>) -> Self._Body
    typealias _Label = _TextFieldStyleLabel
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _TextFieldStyleLabel: View {
    public static func _makeView(view: _GraphValue<_TextFieldStyleLabel>, inputs: _ViewInputs) -> _ViewOutputs {
        _darlingUnsupportedView(Self.self, inputs)
    }
    public typealias Body = Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct PlainTextFieldStyle: TextFieldStyle {
    public init() {}
    public func _body(configuration: TextField<PlainTextFieldStyle._Label>) -> some View { configuration }
}
@available(iOS 13.0, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct RoundedBorderTextFieldStyle: TextFieldStyle {
    public init() {}
    public func _body(configuration: TextField<RoundedBorderTextFieldStyle._Label>) -> some View { configuration }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension View {
    public func textFieldStyle<S>(_ style: S) -> some View where S: TextFieldStyle {
        _darlingIgnoredModifier(self, "textFieldStyle")
    }
}

@available(iOS 15.0, macOS 12.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public protocol TextSelectability {
    static var allowsSelection: Bool { get }
}
@available(iOS 15.0, macOS 12.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct EnabledTextSelectability: TextSelectability {
    public static let allowsSelection = true
    @usableFromInline internal init() {}
}
@available(iOS 15.0, macOS 12.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct DisabledTextSelectability: TextSelectability {
    public static let allowsSelection = false
    @usableFromInline internal init() {}
}
@available(iOS 15.0, macOS 12.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension View {
    public func textSelection<S>(_ selectability: S) -> some View where S: TextSelectability {
        _darlingIgnoredModifier(self, "textSelection")
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Text {
    public init<F>(_ input: F.FormatInput, format: F) where F: FormatStyle, F.FormatInput: Equatable, F.FormatOutput == String {
        self.init(verbatim: format.format(input))
    }
}
