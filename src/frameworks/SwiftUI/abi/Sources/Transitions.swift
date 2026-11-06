// The Transition protocol and OpacityTransition, from the iOS 18.0 SDK's SwiftUICore interface.
// Darling does not animate insertions and removals (see AnyTransition): a Transition's body is not
// evaluated, so PlaceholderContentView, its stand-in for the content, is never made.

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct PlaceholderContentView<Value>: View {
    public static func _makeView(view: _GraphValue<PlaceholderContentView<Value>>, inputs: _ViewInputs) -> _ViewOutputs {
        _abiUnimplemented("PlaceholderContentView._makeView")
    }
    public typealias Body = Never
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct _Transition_ContentTransition {}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@frozen public enum TransitionPhase {
    case willAppear
    case identity
    case didDisappear
    public var isIdentity: Bool { self == .identity }
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct TransitionProperties: Sendable {
    public init(hasMotion: Bool = true) { self.hasMotion = hasMotion }
    public var hasMotion: Bool
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public protocol Transition {
    associatedtype Body: View
    @ViewBuilder func body(content: Self.Content, phase: TransitionPhase) -> Self.Body
    static var properties: TransitionProperties { get }
    typealias Content = PlaceholderContentView<Self>
    func _makeContentTransition(transition: inout _Transition_ContentTransition)
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension Transition {
    public static var properties: TransitionProperties { TransitionProperties() }
    public func _makeContentTransition(transition: inout _Transition_ContentTransition) {}
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct OpacityTransition: Transition {
    public init() {}
    public func body(content: OpacityTransition.Content, phase: TransitionPhase) -> some View {
        content.opacity(phase.isIdentity ? 1 : 0)
    }
    public static let properties = TransitionProperties(hasMotion: false)
}
