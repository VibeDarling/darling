import Foundation
import CoreFoundation

// AnyView and AnyTransition, with the iOS 16.5 SDK's frozen layouts (one reference each).

/// The type-erased view: its box renders the wrapped view. A view of another type is a different
/// view, so its state lives at its own path.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct AnyView : View {
  internal var storage: AnyViewStorageBase
  public init<V>(_ view: V) where V : View {
    if let other = view as? AnyView { storage = other.storage } else { storage = AnyViewStorage(view) }
  }
  public init?(_fromValue value: Any) {
    func wrap<V: View>(_ view: V) -> AnyView { AnyView(view) }
    guard let view = value as? any View else { return nil }
    self = wrap(view)
  }
  public static func _makeView(view: _GraphValue<AnyView>, inputs: _ViewInputs) -> _ViewOutputs {
    view.value.storage.makeView(inputs: inputs)
  }
  public static func _makeViewList(view: _GraphValue<AnyView>, inputs: _ViewListInputs) -> _ViewListOutputs {
    _ViewListOutputs(view: view.value.storage.makeView(inputs: inputs.viewInputs))
  }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal class AnyViewStorageBase {
  init() {}
  func makeView(inputs: _ViewInputs) -> _ViewOutputs { _ViewOutputs(node: RenderNode(kind: "empty")) }
  @objc @usableFromInline
  deinit {}
}

private final class AnyViewStorage<V: View>: AnyViewStorageBase {
  let view: V
  init(_ view: V) { self.view = view }
  override func makeView(inputs: _ViewInputs) -> _ViewOutputs {
    V._makeView(view: _GraphValue(value: view), inputs: inputs.child(ObjectIdentifier(V.self)))
  }
}

/// Darling does not animate insertions and removals: every transition shows and hides its view at
/// once, so they are all the same value.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct AnyTransition {
  fileprivate let box: AnyTransitionBox
  fileprivate static let immediate = AnyTransition(box: AnyTransitionBox())
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal class AnyTransitionBox {
  init() {}
  @objc @usableFromInline
  deinit {}
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public static func offset(_ offset: CoreFoundation.CGSize) -> AnyTransition { .immediate }
  public static func offset(x: CoreFoundation.CGFloat = 0, y: CoreFoundation.CGFloat = 0) -> AnyTransition { .immediate }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public static var scale: AnyTransition {
    get { .immediate }
  }
  public static func scale(scale: CoreFoundation.CGFloat, anchor: UnitPoint = .center) -> AnyTransition { .immediate }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public static let opacity: AnyTransition = .immediate
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public static var slide: AnyTransition {
    get { .immediate }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public func combined(with other: AnyTransition) -> AnyTransition { self }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public static func modifier<E>(active: E, identity: E) -> AnyTransition where E : ViewModifier { .immediate }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public func animation(_ animation: Animation?) -> AnyTransition { self }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public static let identity: AnyTransition = .immediate
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public static func move(edge: Edge) -> AnyTransition { .immediate }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension AnyTransition {
  public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition { .immediate }
}
