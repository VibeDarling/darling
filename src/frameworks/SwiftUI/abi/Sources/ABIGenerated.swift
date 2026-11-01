// Generated from the declarations in the iOS 16.5 SDK's SwiftUI interface (scratchpad abigen.py), so
// the names, frozen layouts and conformances are the ones apps link against. A body the interface
// leaves out is an _abiUnimplemented trap until an app needs it to work.
import Foundation
import CoreFoundation
import CoreGraphics
import UIKit
import Combine
import UniformTypeIdentifiers
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct AccessibilityTraits : Swift.SetAlgebra {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static let isButton: AccessibilityTraits = AccessibilityTraits(_abiTag: 1)
  public static let isHeader: AccessibilityTraits = AccessibilityTraits(_abiTag: 2)
  public static let isSelected: AccessibilityTraits = AccessibilityTraits(_abiTag: 3)
  public static let isLink: AccessibilityTraits = AccessibilityTraits(_abiTag: 4)
  public static let isSearchField: AccessibilityTraits = AccessibilityTraits(_abiTag: 5)
  public static let isImage: AccessibilityTraits = AccessibilityTraits(_abiTag: 6)
  public static let playsSound: AccessibilityTraits = AccessibilityTraits(_abiTag: 7)
  public static let isKeyboardKey: AccessibilityTraits = AccessibilityTraits(_abiTag: 8)
  public static let isStaticText: AccessibilityTraits = AccessibilityTraits(_abiTag: 9)
  public static let isSummaryElement: AccessibilityTraits = AccessibilityTraits(_abiTag: 10)
  public static let updatesFrequently: AccessibilityTraits = AccessibilityTraits(_abiTag: 11)
  public static let startsMediaSession: AccessibilityTraits = AccessibilityTraits(_abiTag: 12)
  public static let allowsDirectInteraction: AccessibilityTraits = AccessibilityTraits(_abiTag: 13)
  public static let causesPageTurn: AccessibilityTraits = AccessibilityTraits(_abiTag: 14)
  public static let isModal: AccessibilityTraits = AccessibilityTraits(_abiTag: 15)
  public init() { self.init(_abiTag: 0); _abiInertValue("AccessibilityTraits") }
  public func union(_ other: AccessibilityTraits) -> AccessibilityTraits { _abiUnimplemented("AccessibilityTraits: public func union(_ other: AccessibilityTraits) -> AccessibilityTraits") }
  public mutating func formUnion(_ other: AccessibilityTraits) { _abiUnimplemented("AccessibilityTraits: public mutating func formUnion(_ other: AccessibilityTraits)") }
  public func intersection(_ other: AccessibilityTraits) -> AccessibilityTraits { _abiUnimplemented("AccessibilityTraits: public func intersection(_ other: AccessibilityTraits) -> AccessibilityTraits") }
  public mutating func formIntersection(_ other: AccessibilityTraits) { _abiUnimplemented("AccessibilityTraits: public mutating func formIntersection(_ other: AccessibilityTraits)") }
  public func symmetricDifference(_ other: AccessibilityTraits) -> AccessibilityTraits { _abiUnimplemented("AccessibilityTraits: public func symmetricDifference(_ other: AccessibilityTraits) -> AccessibilityTraits") }
  public mutating func formSymmetricDifference(_ other: AccessibilityTraits) { _abiUnimplemented("AccessibilityTraits: public mutating func formSymmetricDifference(_ other: AccessibilityTraits)") }
  public func contains(_ member: AccessibilityTraits) -> Swift.Bool { _abiUnimplemented("AccessibilityTraits: public func contains(_ member: AccessibilityTraits) -> Swift.Bool") }
  public mutating func insert(_ newMember: AccessibilityTraits) -> (inserted: Swift.Bool, memberAfterInsert: AccessibilityTraits) { _abiUnimplemented("AccessibilityTraits: public mutating func insert(_ newMember: AccessibilityTraits) -> (inserted: Swift.Bool, memberAfterInsert: Accessibility") }
  public mutating func remove(_ member: AccessibilityTraits) -> AccessibilityTraits? { _abiUnimplemented("AccessibilityTraits: public mutating func remove(_ member: AccessibilityTraits) -> AccessibilityTraits?") }
  public mutating func update(with newMember: AccessibilityTraits) -> AccessibilityTraits? { _abiUnimplemented("AccessibilityTraits: public mutating func update(with newMember: AccessibilityTraits) -> AccessibilityTraits?") }
  public static func == (a: AccessibilityTraits, b: AccessibilityTraits) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias ArrayLiteralElement = AccessibilityTraits
  public typealias Element = AccessibilityTraits
}

@available(iOS, introduced: 13.0, deprecated: 100000.0, message: "use `View.alert(title:isPresented:presenting::actions:) instead.")
@available(macOS, introduced: 10.15, deprecated: 100000.0, message: "use `View.alert(title:isPresented:presenting::actions:) instead.")
@available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "use `View.alert(title:isPresented:presenting::actions:) instead.")
@available(watchOS, introduced: 6.0, deprecated: 100000.0, message: "use `View.alert(title:isPresented:presenting::actions:) instead.")
public struct Alert {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(title: Text, message: Text? = nil, dismissButton: Alert.Button? = nil) { self.init(_abiTag: 0); _abiInertValue("Alert") }
  public init(title: Text, message: Text? = nil, primaryButton: Alert.Button, secondaryButton: Alert.Button) { self.init(_abiTag: 0); _abiInertValue("Alert") }
  @available(iOS, unavailable)
  @available(tvOS, unavailable)
  @available(macOS, unavailable)
  public static func sideBySideButtons(title: Text, message: Text? = nil, primaryButton: Alert.Button, secondaryButton: Alert.Button) -> Alert { _abiUnimplemented("Alert: public static func sideBySideButtons(title: Text, message: Text? = nil, primaryButton: Alert.Button, secondaryButton: Al") }
  public struct Button {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public static func `default`(_ label: Text, action: (() -> Swift.Void)? = {}) -> Alert.Button { _abiUnimplemented("Alert: public static func `default`(_ label: Text, action: (() -> Swift.Void)? = {}) -> Alert.Button") }
    public static func cancel(_ label: Text, action: (() -> Swift.Void)? = {}) -> Alert.Button { _abiUnimplemented("Alert: public static func cancel(_ label: Text, action: (() -> Swift.Void)? = {}) -> Alert.Button") }
    public static func cancel(_ action: (() -> Swift.Void)? = {}) -> Alert.Button { _abiUnimplemented("Alert: public static func cancel(_ action: (() -> Swift.Void)? = {}) -> Alert.Button") }
    public static func destructive(_ label: Text, action: (() -> Swift.Void)? = {}) -> Alert.Button { _abiUnimplemented("Alert: public static func destructive(_ label: Text, action: (() -> Swift.Void)? = {}) -> Alert.Button") }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _AlignmentWritingModifier : ViewModifier {
  @usableFromInline
  internal let key: AlignmentKey
  @usableFromInline
  internal let computeValue: (ViewDimensions) -> CoreFoundation.CGFloat
  @inlinable internal init(key: AlignmentKey, computeValue: @escaping (ViewDimensions) -> CoreFoundation.CGFloat) {
        self.key = key
        self.computeValue = computeValue
    }
  public static func _makeView(modifier: _GraphValue<_AlignmentWritingModifier>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _AllowsHitTestingModifier : Swift.Equatable {
  public var allowsHitTesting: Swift.Bool
  @inlinable public init(allowsHitTesting: Swift.Bool) {
        self.allowsHitTesting = allowsHitTesting
    }
  public static func _makeView(modifier: _GraphValue<_AllowsHitTestingModifier>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public static func == (a: _AllowsHitTestingModifier, b: _AllowsHitTestingModifier) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _AllowsHitTestingModifier : ViewModifier {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _AllowsHitTestingModifier : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct Anchor<Value> {
  fileprivate let box: AnchorValueBoxBase<Value>
  @frozen public struct Source {
    private var box: AnchorBoxBase<Value>
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Anchor.Source where Value == CoreFoundation.CGPoint {
  public static func point(_ p: CoreFoundation.CGPoint) -> Anchor<Value>.Source { _abiUnimplemented("Anchor: public static func point(_ p: CoreFoundation.CGPoint) -> Anchor<Value>.Source") }
  public static func unitPoint(_ p: UnitPoint) -> Anchor<Value>.Source { _abiUnimplemented("Anchor: public static func unitPoint(_ p: UnitPoint) -> Anchor<Value>.Source") }
  public static var topLeading: Anchor<CoreFoundation.CGPoint>.Source {
    get { _abiUnimplemented("Anchor: public static var topLeading: Anchor<CoreFoundation.CGPoint>.Source {") }
  }
  public static var top: Anchor<CoreFoundation.CGPoint>.Source {
    get { _abiUnimplemented("Anchor: public static var top: Anchor<CoreFoundation.CGPoint>.Source {") }
  }
  public static var topTrailing: Anchor<CoreFoundation.CGPoint>.Source {
    get { _abiUnimplemented("Anchor: public static var topTrailing: Anchor<CoreFoundation.CGPoint>.Source {") }
  }
  public static var leading: Anchor<CoreFoundation.CGPoint>.Source {
    get { _abiUnimplemented("Anchor: public static var leading: Anchor<CoreFoundation.CGPoint>.Source {") }
  }
  public static var center: Anchor<CoreFoundation.CGPoint>.Source {
    get { _abiUnimplemented("Anchor: public static var center: Anchor<CoreFoundation.CGPoint>.Source {") }
  }
  public static var trailing: Anchor<CoreFoundation.CGPoint>.Source {
    get { _abiUnimplemented("Anchor: public static var trailing: Anchor<CoreFoundation.CGPoint>.Source {") }
  }
  public static var bottomLeading: Anchor<CoreFoundation.CGPoint>.Source {
    get { _abiUnimplemented("Anchor: public static var bottomLeading: Anchor<CoreFoundation.CGPoint>.Source {") }
  }
  public static var bottom: Anchor<CoreFoundation.CGPoint>.Source {
    get { _abiUnimplemented("Anchor: public static var bottom: Anchor<CoreFoundation.CGPoint>.Source {") }
  }
  public static var bottomTrailing: Anchor<CoreFoundation.CGPoint>.Source {
    get { _abiUnimplemented("Anchor: public static var bottomTrailing: Anchor<CoreFoundation.CGPoint>.Source {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Anchor : Swift.Equatable where Value : Swift.Equatable {
  public static func == (lhs: Anchor<Value>, rhs: Anchor<Value>) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Anchor : Swift.Hashable where Value : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Anchor.Source {
  public init<T>(_ array: [Anchor<T>.Source]) where Value == [T] { _abiUnimplemented("Anchor: public init<T>(_ array: [Anchor<T>.Source]) where Value == [T]") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Anchor.Source {
  public init<T>(_ anchor: Anchor<T>.Source?) where Value == T? { _abiUnimplemented("Anchor: public init<T>(_ anchor: Anchor<T>.Source?) where Value == T?") }
}

@_hasMissingDesignatedInitializers @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal class AnchorBoxBase<T> {
  @objc @usableFromInline
  deinit {}
}

@_hasMissingDesignatedInitializers @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal class AnchorValueBoxBase<T> {
  @objc @usableFromInline
  deinit {}
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct Angle {
  public var radians: Swift.Double
  @inlinable public var degrees: Swift.Double {
    get { return radians * (180.0 / .pi) }
    set { radians = newValue * (.pi / 180.0) }
  }
  @inlinable public init() {
        self.init(radians: 0.0)
    }
  @inlinable public init(radians: Swift.Double) {
        self.radians = radians
    }
  @inlinable public init(degrees: Swift.Double) {
        self.init(radians: degrees * (.pi / 180.0))
    }
  @inlinable public static func radians(_ radians: Swift.Double) -> Angle {
        return Angle(radians: radians)
    }
  @inlinable public static func degrees(_ degrees: Swift.Double) -> Angle {
        return Angle(degrees: degrees)
    }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Angle : Swift.Hashable, Swift.Comparable {
  @inlinable public static func < (lhs: Angle, rhs: Angle) -> Swift.Bool {
        return lhs.radians < rhs.radians
    }
  public static func == (a: Angle, b: Angle) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Angle : Animatable, _VectorMath {
  public var animatableData: Swift.Double {
    get { _abiUnimplemented("Angle: public var animatableData: Swift.Double {") }
    set {}
  }
  @inlinable public static var zero: Angle {
    get {
        return .init()
    }
  }
  public typealias AnimatableData = Swift.Double
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Angle : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _AnimationModifier<Value> : ViewModifier where Value : Swift.Equatable {
  public var animation: Animation?
  public var value: Value
  @inlinable public init(animation: Animation?, value: Value) {
        self.animation = animation
        self.value = value
    }
  public static func _makeView(modifier: _GraphValue<_AnimationModifier<Value>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public static func _makeViewList(modifier: _GraphValue<_AnimationModifier<Value>>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs { body(_Graph(), inputs) }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _AnimationModifier : Swift.Equatable {
  public static func == (a: _AnimationModifier<Value>, b: _AnimationModifier<Value>) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct AnimationTimelineSchedule : TimelineSchedule {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(minimumInterval: Swift.Double? = nil, paused: Swift.Bool = false) { self.init(_abiTag: 0); _abiInertValue("AnimationTimelineSchedule") }
  public func entries(from start: Foundation.Date, mode: TimelineScheduleMode) -> AnimationTimelineSchedule.Entries { _abiUnimplemented("AnimationTimelineSchedule: public func entries(from start: Foundation.Date, mode: TimelineScheduleMode) -> AnimationTimelineSchedule.Entries") }
  public struct Entries : Swift.Sequence, Swift.IteratorProtocol {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public mutating func next() -> Foundation.Date? { _abiUnimplemented("AnimationTimelineSchedule: public mutating func next() -> Foundation.Date?") }
    public typealias Element = Foundation.Date
    public typealias Iterator = AnimationTimelineSchedule.Entries
  }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public struct _AnimationView<Content> : View where Content : Swift.Equatable, Content : View {
  public var content: Content
  public var animation: Animation?
  @inlinable public init(content: Content, animation: Animation?) {
        self.content = content
        self.animation = animation
    }
  public static func _makeView(view: _GraphValue<_AnimationView<Content>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public static func _makeViewList(view: _GraphValue<_AnimationView<Content>>, inputs: _ViewListInputs) -> _ViewListOutputs { _ViewListOutputs(view: _darlingUnsupportedView(Self.self, inputs.viewInputs)) }
  public static func _viewListCount(inputs: _ViewListCountInputs) -> Swift.Int? { nil }
  public typealias Body = Swift.Never
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@frozen public struct AnyGradient : Swift.Hashable, ShapeStyle {
  internal var provider: AnyGradientBox
  public init(_ gradient: Gradient) { _abiUnimplemented("AnyGradient: public init(_ gradient: Gradient)") }
  public func _apply(to shape: inout _ShapeStyle_Shape) { _abiUnimplemented("AnyGradient: public func _apply(to shape: inout _ShapeStyle_Shape)") }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public static func == (lhs: AnyGradient, rhs: AnyGradient) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}

@_inheritsConvenienceInitializers @_hasMissingDesignatedInitializers @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@usableFromInline
internal class AnyGradientBox : AnyShapeStyleBox {
  @objc @usableFromInline
  deinit {}
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct AsyncImage<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(url: Foundation.URL?, scale: CoreFoundation.CGFloat = 1) where Content == Image { self.init(_abiTag: 0); _abiInertValue("AsyncImage") }
  public init(url: Foundation.URL?, scale: CoreFoundation.CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) { self.init(_abiTag: 0); _abiInertValue("AsyncImage") }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("AsyncImage: @preconcurrency @MainActor public var body: some View {") }
  }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public enum AsyncImagePhase {
  case empty
  case success(Image)
  case failure(any Swift.Error)
  public var image: Image? {
    get { _abiUnimplemented("AsyncImagePhase: public var image: Image? {") }
  }
  public var error: (any Swift.Error)? {
    get { _abiUnimplemented("AsyncImagePhase: public var error: (any Swift.Error)? {") }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public enum Axis : Swift.Int8, Swift.CaseIterable {
  case horizontal
  case vertical
  @frozen public struct Set : Swift.OptionSet {
    public typealias Element = Axis.Set
    public let rawValue: Swift.Int8
    public init(rawValue: Swift.Int8) { self.rawValue = rawValue }
    public static let horizontal: Axis.Set = Axis.Set(rawValue: 1 << 0)
    public static let vertical: Axis.Set = Axis.Set(rawValue: 1 << 1)
    public typealias ArrayLiteralElement = Axis.Set.Element
    public typealias RawValue = Swift.Int8
  }
  public init?(rawValue: Swift.Int8) { return nil }
  public typealias AllCases = [Axis]
  public typealias RawValue = Swift.Int8
  public static var allCases: [Axis] {
    get { _abiUnimplemented("Axis: public static var allCases: [Axis] {") }
  }
  public var rawValue: Swift.Int8 {
    get { _abiUnimplemented("Axis: public var rawValue: Swift.Int8 {") }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Axis : Swift.CustomStringConvertible {
  public var description: Swift.String {
    get { _abiUnimplemented("Axis: public var description: Swift.String {") }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Axis : Swift.Equatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Axis : Swift.Hashable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Axis : Swift.RawRepresentable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Axis : Swift.Sendable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Axis.Set : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public enum BlendMode {
  case normal
  case multiply
  case screen
  case overlay
  case darken
  case lighten
  case colorDodge
  case colorBurn
  case softLight
  case hardLight
  case difference
  case exclusion
  case hue
  case saturation
  case color
  case luminosity
  case sourceAtop
  case destinationOver
  case destinationOut
  case plusDarker
  case plusLighter
  public static func == (a: BlendMode, b: BlendMode) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension BlendMode : Swift.Equatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension BlendMode : Swift.Hashable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _BlendModeEffect : Swift.Equatable {
  public var blendMode: BlendMode
  @inlinable public init(blendMode: BlendMode) {
        self.blendMode = blendMode
    }
  public static func == (a: _BlendModeEffect, b: _BlendModeEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias AnimatableData = EmptyAnimatableData
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _BlendModeEffect : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _BlendModeEffect : ViewModifier {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public struct _BlendModeShapeStyle<Style> : ShapeStyle where Style : ShapeStyle {
  public var style: Style
  public var blendMode: BlendMode
  @inlinable public init(style: Style, blendMode: BlendMode) {
        self.style = style
        self.blendMode = blendMode
    }
  public func _apply(to shape: inout _ShapeStyle_Shape) { _abiUnimplemented("_BlendModeShapeStyle: public func _apply(to shape: inout _ShapeStyle_Shape)") }
  public static func _apply(to type: inout _ShapeStyle_ShapeType) { _abiUnimplemented("_BlendModeShapeStyle: public static func _apply(to type: inout _ShapeStyle_ShapeType)") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _BlurEffect : Swift.Equatable {
  public var radius: CoreFoundation.CGFloat
  public var isOpaque: Swift.Bool
  @inlinable public init(radius: CoreFoundation.CGFloat, opaque: Swift.Bool) {
        self.radius = radius
        self.isOpaque = opaque
    }
  public var animatableData: CoreFoundation.CGFloat {
    get { _abiUnimplemented("_BlurEffect: public var animatableData: CoreFoundation.CGFloat {") }
    set {}
  }
  public static func == (a: _BlurEffect, b: _BlurEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias AnimatableData = CoreFoundation.CGFloat
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _BlurEffect : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _BlurEffect : ViewModifier {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _BlurEffect : Swift.Sendable {}

@available(iOS 15.0, macOS 10.15, tvOS 13.0, watchOS 7.0, *)
public struct BorderedButtonStyle : PrimitiveButtonStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("BorderedButtonStyle") }
  @available(iOS, unavailable)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, introduced: 7.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  public init(tint: Color) { self.init(_abiTag: 0); _abiInertValue("BorderedButtonStyle") }
  public func makeBody(configuration: BorderedButtonStyle.Configuration) -> some View { _abiUnimplemented("BorderedButtonStyle: public func makeBody(configuration: BorderedButtonStyle.Configuration) -> some View") }
  
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct BorderedProminentButtonStyle : PrimitiveButtonStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("BorderedProminentButtonStyle") }
  public func makeBody(configuration: BorderedProminentButtonStyle.Configuration) -> some View { _abiUnimplemented("BorderedProminentButtonStyle: public func makeBody(configuration: BorderedProminentButtonStyle.Configuration) -> some View") }
  
}

@available(iOS 13.0, macOS 10.15, watchOS 8.0, *)
@available(tvOS, unavailable)
public struct BorderlessButtonStyle : PrimitiveButtonStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("BorderlessButtonStyle") }
  public func makeBody(configuration: BorderlessButtonStyle.Configuration) -> some View { _abiUnimplemented("BorderlessButtonStyle: public func makeBody(configuration: BorderlessButtonStyle.Configuration) -> some View") }
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol ButtonStyle {
  associatedtype Body : View
  @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
  typealias Configuration = ButtonStyleConfiguration
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ButtonStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public struct Label : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public let role: ButtonRole?
  public let label: ButtonStyleConfiguration.Label
  public let isPressed: Swift.Bool
}

@available(iOS 15.0, macOS 12.0, watchOS 9.0, *)
@available(tvOS, unavailable)
public struct ButtonToggleStyle : ToggleStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("ButtonToggleStyle") }
  public func makeBody(configuration: ButtonToggleStyle.Configuration) -> some View { _abiUnimplemented("ButtonToggleStyle: public func makeBody(configuration: ButtonToggleStyle.Configuration) -> some View") }
  
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct Canvas<Symbols> where Symbols : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public var symbols: Symbols
  public var renderer: (inout GraphicsContext, CoreFoundation.CGSize) -> Swift.Void
  public var isOpaque: Swift.Bool {
    get { _abiUnimplemented("Canvas: public var isOpaque: Swift.Bool {") }
    set {}
  }
  public var colorMode: ColorRenderingMode {
    get { _abiUnimplemented("Canvas: public var colorMode: ColorRenderingMode {") }
    set {}
  }
  public var rendersAsynchronously: Swift.Bool {
    get { _abiUnimplemented("Canvas: public var rendersAsynchronously: Swift.Bool {") }
    set {}
  }
  public init(opaque: Swift.Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Swift.Bool = false, renderer: @escaping (inout GraphicsContext, CoreFoundation.CGSize) -> Swift.Void, @ViewBuilder symbols: () -> Symbols) { self.init(_abiTag: 0); _abiInertValue("Canvas") }
  public static func _makeView(view: _GraphValue<Canvas<Symbols>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public typealias Body = Swift.Never
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Canvas where Symbols == EmptyView {
  public init(opaque: Swift.Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Swift.Bool = false, renderer: @escaping (inout GraphicsContext, CoreFoundation.CGSize) -> Swift.Void) { self.init(_abiTag: 0); _abiInertValue("Canvas") }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Canvas : View {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _ChangedGesture<Content> where Content : Gesture, Content.Value : Swift.Equatable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static func _makeGesture(gesture: _GraphValue<_ChangedGesture<Content>>, inputs: _GestureInputs) -> _GestureOutputs<Content.Value> { _abiUnimplemented("_ChangedGesture: public static func _makeGesture(gesture: _GraphValue<_ChangedGesture<Content>>, inputs: _GestureInputs) -> _GestureOutpu") }
  public typealias Body = Swift.Never
  public typealias Value = Content.Value
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _ChangedGesture : Gesture {}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct CircularProgressViewStyle : ProgressViewStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("CircularProgressViewStyle") }
  @available(iOS, introduced: 14.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  @available(macOS, introduced: 11.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  @available(tvOS, introduced: 14.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  @available(watchOS, introduced: 7.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  public init(tint: Color) { self.init(_abiTag: 0); _abiInertValue("CircularProgressViewStyle") }
  public func makeBody(configuration: CircularProgressViewStyle.Configuration) -> some View { _abiUnimplemented("CircularProgressViewStyle: public func makeBody(configuration: CircularProgressViewStyle.Configuration) -> some View") }
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _ClipEffect<ClipShape> where ClipShape : Shape {
  public var shape: ClipShape
  public var style: FillStyle
  @inlinable public init(shape: ClipShape, style: FillStyle = FillStyle()) {
        self.shape = shape
        self.style = style
    }
  public var animatableData: ClipShape.AnimatableData {
    get { _abiUnimplemented("_ClipEffect: public var animatableData: ClipShape.AnimatableData {") }
    set {}
  }
  public typealias AnimatableData = ClipShape.AnimatableData
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _ClipEffect : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _ClipEffect : ViewModifier {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public struct ColorMatrix : Swift.Equatable {
  public var r1: Swift.Float = 1, r2: Swift.Float = 0, r3: Swift.Float = 0, r4: Swift.Float = 0, r5: Swift.Float = 0
  public var g1: Swift.Float = 0, g2: Swift.Float = 1, g3: Swift.Float = 0, g4: Swift.Float = 0, g5: Swift.Float = 0
  public var b1: Swift.Float = 0, b2: Swift.Float = 0, b3: Swift.Float = 1, b4: Swift.Float = 0, b5: Swift.Float = 0
  public var a1: Swift.Float = 0, a2: Swift.Float = 0, a3: Swift.Float = 0, a4: Swift.Float = 1, a5: Swift.Float = 0
  @inlinable public init() {}
  public static func == (a: ColorMatrix, b: ColorMatrix) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension ColorMatrix : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public enum ColorRenderingMode {
  case nonLinear
  case linear
  case extendedLinear
  public static func == (a: ColorRenderingMode, b: ColorRenderingMode) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ColorRenderingMode : Swift.Equatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ColorRenderingMode : Swift.Hashable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _CompositingGroupEffect : Swift.Equatable {
  @inlinable public init() {}
  public static func == (a: _CompositingGroupEffect, b: _CompositingGroupEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias AnimatableData = EmptyAnimatableData
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _CompositingGroupEffect : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _CompositingGroupEffect : ViewModifier {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _CompositingGroupEffect : Swift.Sendable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public struct _ContentShapeKindModifier<ContentShape> : ViewModifier where ContentShape : Shape {
  public var shape: ContentShape
  public var eoFill: Swift.Bool
  public var kind: ContentShapeKinds
  @inlinable public init(shape: ContentShape, eoFill: Swift.Bool = false, kind: ContentShapeKinds) {
        self.shape = shape
        self.eoFill = eoFill
        self.kind = kind
    }
  public static func _makeView(modifier: _GraphValue<_ContentShapeKindModifier<ContentShape>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public typealias Body = Swift.Never
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct ContentShapeKinds : Swift.OptionSet {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public var rawValue: Swift.Int
  public init(rawValue: Swift.Int) { self.rawValue = rawValue }
  public static let interaction: ContentShapeKinds = ContentShapeKinds(rawValue: 1 << 0)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  public static let dragPreview: ContentShapeKinds = ContentShapeKinds(rawValue: 1 << 1)
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  public static let contextMenuPreview: ContentShapeKinds = ContentShapeKinds(rawValue: 1 << 2)
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  public static let hoverEffect: ContentShapeKinds = ContentShapeKinds(rawValue: 1 << 3)
  @available(iOS, unavailable)
  @available(tvOS, unavailable)
  public static let focusEffect: ContentShapeKinds = ContentShapeKinds(rawValue: 1 << 4)
  public typealias ArrayLiteralElement = ContentShapeKinds
  public typealias Element = ContentShapeKinds
  public typealias RawValue = Swift.Int
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _ContentShapeModifier<ContentShape> : ViewModifier where ContentShape : Shape {
  public var shape: ContentShape
  public var eoFill: Swift.Bool
  @inlinable public init(shape: ContentShape, eoFill: Swift.Bool = false) {
        self.shape = shape
        self.eoFill = eoFill
    }
  public static func _makeView(modifier: _GraphValue<_ContentShapeModifier<ContentShape>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public enum CoordinateSpace {
  case global
  case local
  case named(Swift.AnyHashable)
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension CoordinateSpace : Swift.Equatable, Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public static func == (lhs: CoordinateSpace, rhs: CoordinateSpace) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public protocol CustomPresentationDetent {
  static func height(in context: Self.Context) -> CoreFoundation.CGFloat?
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension CustomPresentationDetent {
  public typealias Context = PresentationDetent.Context
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct DefaultButtonStyle : PrimitiveButtonStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("DefaultButtonStyle") }
  public func makeBody(configuration: DefaultButtonStyle.Configuration) -> some View { _abiUnimplemented("DefaultButtonStyle: public func makeBody(configuration: DefaultButtonStyle.Configuration) -> some View") }
  
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct DefaultLabelStyle : LabelStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("DefaultLabelStyle") }
  public func makeBody(configuration: DefaultLabelStyle.Configuration) -> some View { _abiUnimplemented("DefaultLabelStyle: public func makeBody(configuration: DefaultLabelStyle.Configuration) -> some View") }
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct DefaultListStyle : ListStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("DefaultListStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<DefaultListStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("DefaultListStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<DefaultListStyle, SelectionValue>>, inputs: _") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<DefaultListStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("DefaultListStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<DefaultListStyle, SelectionValue>>, input") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct DefaultPickerStyle : PickerStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("DefaultPickerStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<DefaultPickerStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("DefaultPickerStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<DefaultPickerStyle, SelectionValue>>, input") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<DefaultPickerStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("DefaultPickerStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<DefaultPickerStyle, SelectionValue>>, i") }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct DefaultProgressViewStyle : ProgressViewStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("DefaultProgressViewStyle") }
  public func makeBody(configuration: DefaultProgressViewStyle.Configuration) -> some View { _abiUnimplemented("DefaultProgressViewStyle: public func makeBody(configuration: DefaultProgressViewStyle.Configuration) -> some View") }
  
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct DefaultTabViewStyle : TabViewStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("DefaultTabViewStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_TabViewValue<DefaultTabViewStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("DefaultTabViewStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_TabViewValue<DefaultTabViewStyle, SelectionValue>>, inp") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_TabViewValue<DefaultTabViewStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("DefaultTabViewStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_TabViewValue<DefaultTabViewStyle, SelectionValue>>,") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct DefaultToggleStyle : ToggleStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("DefaultToggleStyle") }
  public func makeBody(configuration: DefaultToggleStyle.Configuration) -> some View { _abiUnimplemented("DefaultToggleStyle: public func makeBody(configuration: DefaultToggleStyle.Configuration) -> some View") }
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _DelayedPreferenceView<Key, Content> : View where Key : PreferenceKey, Content : View {
  public var transform: (_PreferenceValue<Key>) -> Content
  @inlinable public init(transform: @escaping (_PreferenceValue<Key>) -> Content) {
        self.transform = transform
    }
  public static func _makeView(view: _GraphValue<_DelayedPreferenceView<Key, Content>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public typealias Body = Swift.Never
}

@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct DisclosureGroup<Label, Content> : View where Label : View, Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) { self.init(_abiTag: 0); _abiInertValue("DisclosureGroup") }
  public init(isExpanded: Binding<Swift.Bool>, @ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) { self.init(_abiTag: 0); _abiInertValue("DisclosureGroup") }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("DisclosureGroup: @preconcurrency @MainActor public var body: some View {") }
  }
}
@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension DisclosureGroup where Label == Text {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) { self.init(_abiTag: 0); _abiInertValue("DisclosureGroup") }
  public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Swift.Bool>, @ViewBuilder content: @escaping () -> Content) { self.init(_abiTag: 0); _abiInertValue("DisclosureGroup") }
  @_disfavoredOverload public init<S>(_ label: S, @ViewBuilder content: @escaping () -> Content) where S : Swift.StringProtocol { _abiUnimplemented("DisclosureGroup: @_disfavoredOverload public init<S>(_ label: S, @ViewBuilder content: @escaping () -> Content) where S : Swift.StringPro") }
  @_disfavoredOverload public init<S>(_ label: S, isExpanded: Binding<Swift.Bool>, @ViewBuilder content: @escaping () -> Content) where S : Swift.StringProtocol { _abiUnimplemented("DisclosureGroup: @_disfavoredOverload public init<S>(_ label: S, isExpanded: Binding<Swift.Bool>, @ViewBuilder content: @escaping () -> C") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Divider : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("Divider") }
  public static func _makeView(view: _GraphValue<Divider>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@available(tvOS, unavailable)
public struct DragGesture : Gesture {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public struct Value : Swift.Equatable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
    public var time: Foundation.Date
    public var location: CoreFoundation.CGPoint
    public var startLocation: CoreFoundation.CGPoint
    public var translation: CoreFoundation.CGSize {
      get { _abiUnimplemented("DragGesture: public var translation: CoreFoundation.CGSize {") }
    }
    public var predictedEndLocation: CoreFoundation.CGPoint {
      get { _abiUnimplemented("DragGesture: public var predictedEndLocation: CoreFoundation.CGPoint {") }
    }
    public var predictedEndTranslation: CoreFoundation.CGSize {
      get { _abiUnimplemented("DragGesture: public var predictedEndTranslation: CoreFoundation.CGSize {") }
    }
    public static func == (a: DragGesture.Value, b: DragGesture.Value) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  }
  public var minimumDistance: CoreFoundation.CGFloat
  public var coordinateSpace: CoordinateSpace
  public init(minimumDistance: CoreFoundation.CGFloat = 10, coordinateSpace: CoordinateSpace = .local) { self.init(_abiTag: 0); _abiInertValue("DragGesture") }
  public static func _makeGesture(gesture: _GraphValue<DragGesture>, inputs: _GestureInputs) -> _GestureOutputs<DragGesture.Value> { _abiUnimplemented("DragGesture: public static func _makeGesture(gesture: _GraphValue<DragGesture>, inputs: _GestureInputs) -> _GestureOutputs<DragGestur") }
  public typealias Body = Swift.Never
}

@available(iOS 13.4, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@preconcurrency @MainActor public protocol DropDelegate {
  @preconcurrency @MainActor func validateDrop(info: DropInfo) -> Swift.Bool
  @preconcurrency @MainActor func performDrop(info: DropInfo) -> Swift.Bool
  @preconcurrency @MainActor func dropEntered(info: DropInfo)
  @preconcurrency @MainActor func dropUpdated(info: DropInfo) -> DropProposal?
  @preconcurrency @MainActor func dropExited(info: DropInfo)
}
@available(iOS 13.4, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension DropDelegate {
  @preconcurrency @MainActor public func validateDrop(info: DropInfo) -> Swift.Bool { _abiUnimplemented("DropDelegate: @preconcurrency @MainActor public func validateDrop(info: DropInfo) -> Swift.Bool") }
  @preconcurrency @MainActor public func dropEntered(info: DropInfo) { _abiUnimplemented("DropDelegate: @preconcurrency @MainActor public func dropEntered(info: DropInfo)") }
  @preconcurrency @MainActor public func dropUpdated(info: DropInfo) -> DropProposal? { _abiUnimplemented("DropDelegate: @preconcurrency @MainActor public func dropUpdated(info: DropInfo) -> DropProposal?") }
  @preconcurrency @MainActor public func dropExited(info: DropInfo) { _abiUnimplemented("DropDelegate: @preconcurrency @MainActor public func dropExited(info: DropInfo)") }
}

@available(iOS 13.4, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct DropInfo {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public var location: CoreFoundation.CGPoint {
    get { _abiUnimplemented("DropInfo: public var location: CoreFoundation.CGPoint {") }
  }
  @available(iOS 14.0, macOS 11.0, *)
  public func hasItemsConforming(to contentTypes: [UniformTypeIdentifiers.UTType]) -> Swift.Bool { _abiUnimplemented("DropInfo: public func hasItemsConforming(to contentTypes: [UniformTypeIdentifiers.UTType]) -> Swift.Bool") }
  @available(iOS 14.0, macOS 11.0, *)
  public func itemProviders(for contentTypes: [UniformTypeIdentifiers.UTType]) -> [Foundation.NSItemProvider] { _abiUnimplemented("DropInfo: public func itemProviders(for contentTypes: [UniformTypeIdentifiers.UTType]) -> [Foundation.NSItemProvider]") }
}

@available(iOS 13.4, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public enum DropOperation {
  case cancel
  case forbidden
  case copy
  case move
  public static func == (a: DropOperation, b: DropOperation) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 13.4, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension DropOperation : Swift.Equatable {}
@available(iOS 13.4, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension DropOperation : Swift.Hashable {}

@available(iOS 13.4, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct DropProposal {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public let operation: DropOperation
  public init(operation: DropOperation) { self.init(_abiTag: 0); _abiInertValue("DropProposal") }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public enum DynamicTypeSize : Swift.Hashable, Swift.Comparable, Swift.CaseIterable {
  case xSmall
  case small
  case medium
  case large
  case xLarge
  case xxLarge
  case xxxLarge
  case accessibility1
  case accessibility2
  case accessibility3
  case accessibility4
  case accessibility5
  public var isAccessibilitySize: Swift.Bool {
    get { _abiUnimplemented("DynamicTypeSize: public var isAccessibilitySize: Swift.Bool {") }
  }
  public static func < (a: DynamicTypeSize, b: DynamicTypeSize) -> Swift.Bool { _abiUnimplemented("DynamicTypeSize: public static func < (a: DynamicTypeSize, b: DynamicTypeSize) -> Swift.Bool") }
  public static func == (a: DynamicTypeSize, b: DynamicTypeSize) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public typealias AllCases = [DynamicTypeSize]
  public static var allCases: [DynamicTypeSize] {
    get { _abiUnimplemented("DynamicTypeSize: public static var allCases: [DynamicTypeSize] {") }
  }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 15.0, tvOS 15.0, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
extension DynamicTypeSize {
  public init?(_ uiSizeCategory: UIKit.UIContentSizeCategory) { return nil }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol DynamicViewContent : View {
  associatedtype Data : Swift.Collection
  var data: Self.Data { get }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension DynamicViewContent {
  @inlinable public func onDelete(perform action: Swift.Optional<(Foundation.IndexSet) -> Swift.Void>) -> some DynamicViewContent {
        return modifier(_TraitWritingModifier<OnDeleteTraitKey>(value: action))
    }
  
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension DynamicViewContent {
  @inlinable public func onMove(perform action: Swift.Optional<(Foundation.IndexSet, Swift.Int) -> Swift.Void>) -> some DynamicViewContent {
        modifier(_TraitWritingModifier<OnMoveTraitKey>(value: action))
    }
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _EndedGesture<Content> where Content : Gesture {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static func _makeGesture(gesture: _GraphValue<_EndedGesture<Content>>, inputs: _GestureInputs) -> _GestureOutputs<Content.Value> { _abiUnimplemented("_EndedGesture: public static func _makeGesture(gesture: _GraphValue<_EndedGesture<Content>>, inputs: _GestureInputs) -> _GestureOutputs") }
  public typealias Body = Swift.Never
  public typealias Value = Content.Value
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _EndedGesture : Gesture {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol EnvironmentalModifier : ViewModifier where Self.Body == Swift.Never {
  associatedtype ResolvedModifier : ViewModifier
  func resolve(in environment: EnvironmentValues) -> Self.ResolvedModifier
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  static var _requiresMainThread: Swift.Bool { get }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension EnvironmentalModifier {
  public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public static func _makeViewList(modifier: _GraphValue<Self>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs { body(_Graph(), inputs) }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public static var _requiresMainThread: Swift.Bool {
    get { _abiUnimplemented("EnvironmentalModifier: public static var _requiresMainThread: Swift.Bool {") }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct EventModifiers : Swift.OptionSet {
  public let rawValue: Swift.Int
  public init(rawValue: Swift.Int) { self.rawValue = rawValue }
  public static let capsLock: EventModifiers = EventModifiers(rawValue: 1 << 0)
  public static let shift: EventModifiers = EventModifiers(rawValue: 1 << 1)
  public static let control: EventModifiers = EventModifiers(rawValue: 1 << 2)
  public static let option: EventModifiers = EventModifiers(rawValue: 1 << 3)
  public static let command: EventModifiers = EventModifiers(rawValue: 1 << 4)
  public static let numericPad: EventModifiers = EventModifiers(rawValue: 1 << 5)
  @available(iOS, deprecated: 15.0, message: "Function modifier is reserved for system applications")
  @available(macOS, deprecated: 12.0, message: "Function modifier is reserved for system applications")
  @available(tvOS, deprecated: 15.0, message: "Function modifier is reserved for system applications")
  @available(watchOS, deprecated: 8.0, message: "Function modifier is reserved for system applications")
  public static let function: EventModifiers = EventModifiers(rawValue: 1 << 6)
  public static let all: EventModifiers = EventModifiers(rawValue: 1 << 7)
  public typealias ArrayLiteralElement = EventModifiers
  public typealias Element = EventModifiers
  public typealias RawValue = Swift.Int
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension EventModifiers : Swift.Sendable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct EveryMinuteTimelineSchedule : TimelineSchedule {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public struct Entries : Swift.Sequence, Swift.IteratorProtocol {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public mutating func next() -> Foundation.Date? { _abiUnimplemented("EveryMinuteTimelineSchedule: public mutating func next() -> Foundation.Date?") }
    public typealias Element = Foundation.Date
    public typealias Iterator = EveryMinuteTimelineSchedule.Entries
  }
  public init() { self.init(_abiTag: 0); _abiInertValue("EveryMinuteTimelineSchedule") }
  public func entries(from startDate: Foundation.Date, mode: TimelineScheduleMode) -> EveryMinuteTimelineSchedule.Entries { _abiUnimplemented("EveryMinuteTimelineSchedule: public func entries(from startDate: Foundation.Date, mode: TimelineScheduleMode) -> EveryMinuteTimelineSchedule.Entries") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct ExclusiveGesture<First, Second> : Gesture where First : Gesture, Second : Gesture {
  @frozen public enum Value {
    case first(First.Value)
    case second(Second.Value)
  }
  public var first: First
  public var second: Second
  @inlinable public init(_ first: First, _ second: Second) {
        (self.first, self.second) = (first, second)
    }
  public static func _makeGesture(gesture: _GraphValue<ExclusiveGesture<First, Second>>, inputs: _GestureInputs) -> _GestureOutputs<ExclusiveGesture<First, Second>.Value> { _abiUnimplemented("ExclusiveGesture: public static func _makeGesture(gesture: _GraphValue<ExclusiveGesture<First, Second>>, inputs: _GestureInputs) -> _Gestu") }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ExclusiveGesture.Value : Swift.Equatable where First.Value : Swift.Equatable, Second.Value : Swift.Equatable {
  public static func == (a: ExclusiveGesture<First, Second>.Value, b: ExclusiveGesture<First, Second>.Value) -> Swift.Bool { _abiUnimplemented("ExclusiveGesture: public static func == (a: ExclusiveGesture<First, Second>.Value, b: ExclusiveGesture<First, Second>.Value) -> Swift.Bool") }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct ExplicitTimelineSchedule<Entries> : TimelineSchedule where Entries : Swift.Sequence, Entries.Element == Foundation.Date {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(_ dates: Entries) { self.init(_abiTag: 0); _abiInertValue("ExplicitTimelineSchedule") }
  public func entries(from startDate: Foundation.Date, mode: TimelineScheduleMode) -> Entries { _abiUnimplemented("ExplicitTimelineSchedule: public func entries(from startDate: Foundation.Date, mode: TimelineScheduleMode) -> Entries") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Form<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(@ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("Form") }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("Form: @preconcurrency @MainActor public var body: some View {") }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Form where Content == FormStyleConfiguration.Content {
  public init(_ configuration: FormStyleConfiguration) { self.init(_abiTag: 0); _abiInertValue("Form") }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct FormStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public struct Content : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  public let content: FormStyleConfiguration.Content
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol GeometryEffect : Animatable, ViewModifier where Self.Body == Swift.Never {
  func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform
  static var _affectsLayout: Swift.Bool { get }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension GeometryEffect {
  public static var _affectsLayout: Swift.Bool {
    get { _abiUnimplemented("GeometryEffect: public static var _affectsLayout: Swift.Bool {") }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension GeometryEffect {
  public static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public static func _makeViewList(modifier: _GraphValue<Self>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs { body(_Graph(), inputs) }
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public static func _viewListCount(inputs: _ViewListCountInputs, body: (_ViewListCountInputs) -> Swift.Int?) -> Swift.Int? { nil }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension GeometryEffect {
  @inlinable public func ignoredByLayout() -> _IgnoredByLayoutEffect<Self> {
        return _IgnoredByLayoutEffect(self)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol Gesture {
  associatedtype Value
  static func _makeGesture(gesture: _GraphValue<Self>, inputs: _GestureInputs) -> _GestureOutputs<Self.Value>
  associatedtype Body : Gesture
  var body: Self.Body { get }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Gesture {
  @inlinable public func sequenced<Other>(before other: Other) -> SequenceGesture<Self, Other> where Other : Gesture {
        return SequenceGesture(self, other)
    }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Gesture {
  @inlinable public func simultaneously<Other>(with other: Other) -> SimultaneousGesture<Self, Other> where Other : Gesture {
        return SimultaneousGesture(self, other)
    }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Gesture where Self.Value == Self.Body.Value {
  public static func _makeGesture(gesture: _GraphValue<Self>, inputs: _GestureInputs) -> _GestureOutputs<Self.Body.Value> { _abiUnimplemented("Gesture: public static func _makeGesture(gesture: _GraphValue<Self>, inputs: _GestureInputs) -> _GestureOutputs<Self.Body.Value>") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Gesture {
  public func onEnded(_ action: @escaping (Self.Value) -> Swift.Void) -> _EndedGesture<Self> { _abiUnimplemented("Gesture: public func onEnded(_ action: @escaping (Self.Value) -> Swift.Void) -> _EndedGesture<Self>") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Gesture where Self.Value : Swift.Equatable {
  public func onChanged(_ action: @escaping (Self.Value) -> Swift.Void) -> _ChangedGesture<Self> { _abiUnimplemented("Gesture: public func onChanged(_ action: @escaping (Self.Value) -> Swift.Void) -> _ChangedGesture<Self>") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Gesture {
  public func map<T>(_ body: @escaping (Self.Value) -> T) -> _MapGesture<Self, T> { _abiUnimplemented("Gesture: public func map<T>(_ body: @escaping (Self.Value) -> T) -> _MapGesture<Self, T>") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Gesture {
  @inlinable public func exclusively<Other>(before other: Other) -> ExclusiveGesture<Self, Other> where Other : Gesture {
        return ExclusiveGesture(self, other)
    }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Gesture {
  @inlinable public func updating<State>(_ state: GestureState<State>, body: @escaping (Self.Value, inout State, inout Transaction) -> Swift.Void) -> GestureStateGesture<Self, State> {
        return .init(base: self, state: state, body: body)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _GestureInputs {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct GestureMask : Swift.OptionSet {
  public let rawValue: Swift.UInt32
  public init(rawValue: Swift.UInt32) { self.rawValue = rawValue }
  public static let none: GestureMask = GestureMask(rawValue: 1 << 0)
  public static let gesture: GestureMask = GestureMask(rawValue: 1 << 1)
  public static let subviews: GestureMask = GestureMask(rawValue: 1 << 2)
  public static let all: GestureMask = GestureMask(rawValue: 1 << 3)
  public typealias ArrayLiteralElement = GestureMask
  public typealias Element = GestureMask
  public typealias RawValue = Swift.UInt32
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension GestureMask : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _GestureOutputs<Value> {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct GestureStateGesture<Base, State> : Gesture where Base : Gesture {
  public typealias Value = Base.Value
  public var base: Base
  public var state: GestureState<State>
  public var body: (GestureStateGesture<Base, State>.Value, inout State, inout Transaction) -> Swift.Void
  @inlinable public init(base: Base, state: GestureState<State>, body: @escaping (GestureStateGesture<Base, State>.Value, inout State, inout Transaction) -> Swift.Void) {
        self.base = base
        self.state = state
        self.body = body
    }
  public static func _makeGesture(gesture: _GraphValue<GestureStateGesture<Base, State>>, inputs: _GestureInputs) -> _GestureOutputs<GestureStateGesture<Base, State>.Value> { _abiUnimplemented("GestureStateGesture: public static func _makeGesture(gesture: _GraphValue<GestureStateGesture<Base, State>>, inputs: _GestureInputs) -> _Gest") }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct Gradient : Swift.Equatable {
  @frozen public struct Stop : Swift.Equatable {
    public var color: Color
    public var location: CoreFoundation.CGFloat
    public init(color: Color, location: CoreFoundation.CGFloat) { _abiUnimplemented("Gradient: public init(color: Color, location: CoreFoundation.CGFloat)") }
    public static func == (a: Gradient.Stop, b: Gradient.Stop) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  }
  public var stops: [Gradient.Stop]
  public init(stops: [Gradient.Stop]) { _abiUnimplemented("Gradient: public init(stops: [Gradient.Stop])") }
  public init(colors: [Color]) { _abiUnimplemented("Gradient: public init(colors: [Color])") }
  public static func == (a: Gradient, b: Gradient) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Gradient {
  public struct ColorSpace : Swift.Hashable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public static let device: Gradient.ColorSpace = { _abiUnimplemented("Gradient.device") }()
    public static let perceptual: Gradient.ColorSpace = { _abiUnimplemented("Gradient.perceptual") }()
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public static func == (a: Gradient.ColorSpace, b: Gradient.ColorSpace) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
  public func colorSpace(_ space: Gradient.ColorSpace) -> AnyGradient { _abiUnimplemented("Gradient: public func colorSpace(_ space: Gradient.ColorSpace) -> AnyGradient") }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Gradient : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Gradient.Stop : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Gradient : ShapeStyle {
  public func _apply(to shape: inout _ShapeStyle_Shape) { _abiUnimplemented("Gradient: public func _apply(to shape: inout _ShapeStyle_Shape)") }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public struct GraphicsContext {
  @_hasMissingDesignatedInitializers @usableFromInline
  final internal class Storage {
    @objc deinit {}
  }
  internal var storage: GraphicsContext.Storage
  @frozen public struct BlendMode : Swift.RawRepresentable, Swift.Equatable {
    public let rawValue: Swift.Int32
    @inlinable public init(rawValue: Swift.Int32) { self.rawValue = rawValue }
    @inlinable public static var normal: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.normal.rawValue)
        }
    }
    @inlinable public static var multiply: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.multiply.rawValue)
        }
    }
    @inlinable public static var screen: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.screen.rawValue)
        }
    }
    @inlinable public static var overlay: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.overlay.rawValue)
        }
    }
    @inlinable public static var darken: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.darken.rawValue)
        }
    }
    @inlinable public static var lighten: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.lighten.rawValue)
        }
    }
    @inlinable public static var colorDodge: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.colorDodge.rawValue)
        }
    }
    @inlinable public static var colorBurn: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.colorBurn.rawValue)
        }
    }
    @inlinable public static var softLight: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.softLight.rawValue)
        }
    }
    @inlinable public static var hardLight: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.hardLight.rawValue)
        }
    }
    @inlinable public static var difference: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.difference.rawValue)
        }
    }
    @inlinable public static var exclusion: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.exclusion.rawValue)
        }
    }
    @inlinable public static var hue: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.hue.rawValue)
        }
    }
    @inlinable public static var saturation: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.saturation.rawValue)
        }
    }
    @inlinable public static var color: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.color.rawValue)
        }
    }
    @inlinable public static var luminosity: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.luminosity.rawValue)
        }
    }
    @inlinable public static var clear: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.clear.rawValue)
        }
    }
    @inlinable public static var copy: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.copy.rawValue)
        }
    }
    @inlinable public static var sourceIn: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.sourceIn.rawValue)
        }
    }
    @inlinable public static var sourceOut: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.sourceOut.rawValue)
        }
    }
    @inlinable public static var sourceAtop: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.sourceAtop.rawValue)
        }
    }
    @inlinable public static var destinationOver: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.destinationOver.rawValue)
        }
    }
    @inlinable public static var destinationIn: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.destinationIn.rawValue)
        }
    }
    @inlinable public static var destinationOut: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.destinationOut.rawValue)
        }
    }
    @inlinable public static var destinationAtop: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.destinationAtop.rawValue)
        }
    }
    @inlinable public static var xor: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.xor.rawValue)
        }
    }
    @inlinable public static var plusDarker: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.plusDarker.rawValue)
        }
    }
    @inlinable public static var plusLighter: GraphicsContext.BlendMode {
      get {
            self.init(rawValue: CGBlendMode.plusLighter.rawValue)
        }
    }
    public typealias RawValue = Swift.Int32
  }
  public var opacity: Swift.Double {
    get { _abiUnimplemented("GraphicsContext: public var opacity: Swift.Double {") }
    set {}
  }
  public var blendMode: GraphicsContext.BlendMode {
    get { _abiUnimplemented("GraphicsContext: public var blendMode: GraphicsContext.BlendMode {") }
    set {}
  }
  public var environment: EnvironmentValues {
    get { _abiUnimplemented("GraphicsContext: public var environment: EnvironmentValues {") }
  }
  public var transform: CoreFoundation.CGAffineTransform {
    get { _abiUnimplemented("GraphicsContext: public var transform: CoreFoundation.CGAffineTransform {") }
    set {}
  }
  public mutating func scaleBy(x: CoreFoundation.CGFloat, y: CoreFoundation.CGFloat) { _abiUnimplemented("GraphicsContext: public mutating func scaleBy(x: CoreFoundation.CGFloat, y: CoreFoundation.CGFloat)") }
  public mutating func translateBy(x: CoreFoundation.CGFloat, y: CoreFoundation.CGFloat) { _abiUnimplemented("GraphicsContext: public mutating func translateBy(x: CoreFoundation.CGFloat, y: CoreFoundation.CGFloat)") }
  public mutating func rotate(by angle: Angle) { _abiUnimplemented("GraphicsContext: public mutating func rotate(by angle: Angle)") }
  public mutating func concatenate(_ matrix: CoreFoundation.CGAffineTransform) { _abiUnimplemented("GraphicsContext: public mutating func concatenate(_ matrix: CoreFoundation.CGAffineTransform)") }
  @frozen public struct ClipOptions : Swift.OptionSet {
    public let rawValue: Swift.UInt32
    @inlinable public init(rawValue: Swift.UInt32) { self.rawValue = rawValue }
    @inlinable public static var inverse: GraphicsContext.ClipOptions {
      get { Self(rawValue: 1 << 0) }
    }
    public typealias ArrayLiteralElement = GraphicsContext.ClipOptions
    public typealias Element = GraphicsContext.ClipOptions
    public typealias RawValue = Swift.UInt32
  }
  public var clipBoundingRect: CoreFoundation.CGRect {
    get { _abiUnimplemented("GraphicsContext: public var clipBoundingRect: CoreFoundation.CGRect {") }
  }
  public mutating func clip(to path: Path, style: FillStyle = FillStyle(), options: GraphicsContext.ClipOptions = ClipOptions()) { _abiUnimplemented("GraphicsContext: public mutating func clip(to path: Path, style: FillStyle = FillStyle(), options: GraphicsContext.ClipOptions = ClipOpti") }
  public mutating func clipToLayer(opacity: Swift.Double = 1, options: GraphicsContext.ClipOptions = ClipOptions(), content: (inout GraphicsContext) throws -> Swift.Void) rethrows { _abiUnimplemented("GraphicsContext: public mutating func clipToLayer(opacity: Swift.Double = 1, options: GraphicsContext.ClipOptions = ClipOptions(), conten") }
  public struct Filter {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public static func projectionTransform(_ matrix: ProjectionTransform) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func projectionTransform(_ matrix: ProjectionTransform) -> GraphicsContext.Filter") }
    public static func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CoreFoundation.CGFloat, x: CoreFoundation.CGFloat = 0, y: CoreFoundation.CGFloat = 0, blendMode: GraphicsContext.BlendMode = .normal, options: GraphicsContext.ShadowOptions = ShadowOptions()) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CoreFoundation.CGFloat, x:") }
    public static func colorMultiply(_ color: Color) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func colorMultiply(_ color: Color) -> GraphicsContext.Filter") }
    public static func colorMatrix(_ matrix: ColorMatrix) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func colorMatrix(_ matrix: ColorMatrix) -> GraphicsContext.Filter") }
    public static func hueRotation(_ angle: Angle) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func hueRotation(_ angle: Angle) -> GraphicsContext.Filter") }
    public static func saturation(_ amount: Swift.Double) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func saturation(_ amount: Swift.Double) -> GraphicsContext.Filter") }
    public static func brightness(_ amount: Swift.Double) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func brightness(_ amount: Swift.Double) -> GraphicsContext.Filter") }
    public static func contrast(_ amount: Swift.Double) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func contrast(_ amount: Swift.Double) -> GraphicsContext.Filter") }
    public static func colorInvert(_ amount: Swift.Double = 1) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func colorInvert(_ amount: Swift.Double = 1) -> GraphicsContext.Filter") }
    public static func grayscale(_ amount: Swift.Double) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func grayscale(_ amount: Swift.Double) -> GraphicsContext.Filter") }
    public static var luminanceToAlpha: GraphicsContext.Filter {
      get { _abiUnimplemented("GraphicsContext: public static var luminanceToAlpha: GraphicsContext.Filter {") }
    }
    public static func blur(radius: CoreFoundation.CGFloat, options: GraphicsContext.BlurOptions = BlurOptions()) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func blur(radius: CoreFoundation.CGFloat, options: GraphicsContext.BlurOptions = BlurOptions()) -> Graphic") }
    public static func alphaThreshold(min: Swift.Double, max: Swift.Double = 1, color: Color = Color.black) -> GraphicsContext.Filter { _abiUnimplemented("GraphicsContext: public static func alphaThreshold(min: Swift.Double, max: Swift.Double = 1, color: Color = Color.black) -> GraphicsConte") }
  }
  @frozen public struct ShadowOptions : Swift.OptionSet {
    public let rawValue: Swift.UInt32
    @inlinable public init(rawValue: Swift.UInt32) { self.rawValue = rawValue }
    @inlinable public static var shadowAbove: GraphicsContext.ShadowOptions {
      get { Self(rawValue: 1 << 0) }
    }
    @inlinable public static var shadowOnly: GraphicsContext.ShadowOptions {
      get { Self(rawValue: 1 << 1) }
    }
    @inlinable public static var invertsAlpha: GraphicsContext.ShadowOptions {
      get { Self(rawValue: 1 << 2) }
    }
    @inlinable public static var disablesGroup: GraphicsContext.ShadowOptions {
      get { Self(rawValue: 1 << 3) }
    }
    public typealias ArrayLiteralElement = GraphicsContext.ShadowOptions
    public typealias Element = GraphicsContext.ShadowOptions
    public typealias RawValue = Swift.UInt32
  }
  @frozen public struct BlurOptions : Swift.OptionSet {
    public let rawValue: Swift.UInt32
    @inlinable public init(rawValue: Swift.UInt32) { self.rawValue = rawValue }
    @inlinable public static var opaque: GraphicsContext.BlurOptions {
      get { Self(rawValue: 1 << 0) }
    }
    @inlinable public static var dithersResult: GraphicsContext.BlurOptions {
      get { Self(rawValue: 1 << 1) }
    }
    public typealias ArrayLiteralElement = GraphicsContext.BlurOptions
    public typealias Element = GraphicsContext.BlurOptions
    public typealias RawValue = Swift.UInt32
  }
  @frozen public struct FilterOptions : Swift.OptionSet {
    public let rawValue: Swift.UInt32
    @inlinable public init(rawValue: Swift.UInt32) {
            self.rawValue = rawValue
        }
    @inlinable public static var linearColor: GraphicsContext.FilterOptions {
      get { Self(rawValue: 1 << 0) }
    }
    public typealias ArrayLiteralElement = GraphicsContext.FilterOptions
    public typealias Element = GraphicsContext.FilterOptions
    public typealias RawValue = Swift.UInt32
  }
  public mutating func addFilter(_ filter: GraphicsContext.Filter, options: GraphicsContext.FilterOptions = FilterOptions()) { _abiUnimplemented("GraphicsContext: public mutating func addFilter(_ filter: GraphicsContext.Filter, options: GraphicsContext.FilterOptions = FilterOptions(") }
  public struct Shading {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public static var backdrop: GraphicsContext.Shading {
      get { _abiUnimplemented("GraphicsContext: public static var backdrop: GraphicsContext.Shading {") }
    }
    public static var foreground: GraphicsContext.Shading {
      get { _abiUnimplemented("GraphicsContext: public static var foreground: GraphicsContext.Shading {") }
    }
    public static func palette(_ array: [GraphicsContext.Shading]) -> GraphicsContext.Shading { _abiUnimplemented("GraphicsContext: public static func palette(_ array: [GraphicsContext.Shading]) -> GraphicsContext.Shading") }
    public static func color(_ color: Color) -> GraphicsContext.Shading { _abiUnimplemented("GraphicsContext: public static func color(_ color: Color) -> GraphicsContext.Shading") }
    public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, red: Swift.Double, green: Swift.Double, blue: Swift.Double, opacity: Swift.Double = 1) -> GraphicsContext.Shading { _abiUnimplemented("GraphicsContext: public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, red: Swift.Double, green: Swift.Double, blue: Swift.") }
    public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, white: Swift.Double, opacity: Swift.Double = 1) -> GraphicsContext.Shading { _abiUnimplemented("GraphicsContext: public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, white: Swift.Double, opacity: Swift.Double = 1) -> G") }
    public static func style<S>(_ style: S) -> GraphicsContext.Shading where S : ShapeStyle { _abiUnimplemented("GraphicsContext: public static func style<S>(_ style: S) -> GraphicsContext.Shading where S : ShapeStyle") }
    public static func linearGradient(_ gradient: Gradient, startPoint: CoreFoundation.CGPoint, endPoint: CoreFoundation.CGPoint, options: GraphicsContext.GradientOptions = GradientOptions()) -> GraphicsContext.Shading { _abiUnimplemented("GraphicsContext: public static func linearGradient(_ gradient: Gradient, startPoint: CoreFoundation.CGPoint, endPoint: CoreFoundation.CGP") }
    public static func radialGradient(_ gradient: Gradient, center: CoreFoundation.CGPoint, startRadius: CoreFoundation.CGFloat, endRadius: CoreFoundation.CGFloat, options: GraphicsContext.GradientOptions = GradientOptions()) -> GraphicsContext.Shading { _abiUnimplemented("GraphicsContext: public static func radialGradient(_ gradient: Gradient, center: CoreFoundation.CGPoint, startRadius: CoreFoundation.CGFl") }
    public static func conicGradient(_ gradient: Gradient, center: CoreFoundation.CGPoint, angle: Angle = Angle(), options: GraphicsContext.GradientOptions = GradientOptions()) -> GraphicsContext.Shading { _abiUnimplemented("GraphicsContext: public static func conicGradient(_ gradient: Gradient, center: CoreFoundation.CGPoint, angle: Angle = Angle(), options: ") }
    public static func tiledImage(_ image: Image, origin: CoreFoundation.CGPoint = .zero, sourceRect: CoreFoundation.CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CoreFoundation.CGFloat = 1) -> GraphicsContext.Shading { _abiUnimplemented("GraphicsContext: public static func tiledImage(_ image: Image, origin: CoreFoundation.CGPoint = .zero, sourceRect: CoreFoundation.CGRect ") }
  }
  @frozen public struct GradientOptions : Swift.OptionSet {
    public let rawValue: Swift.UInt32
    @inlinable public init(rawValue: Swift.UInt32) { self.rawValue = rawValue }
    @inlinable public static var `repeat`: GraphicsContext.GradientOptions {
      get { Self(rawValue: 1 << 0) }
    }
    @inlinable public static var mirror: GraphicsContext.GradientOptions {
      get { Self(rawValue: 1 << 1) }
    }
    @inlinable public static var linearColor: GraphicsContext.GradientOptions {
      get { Self(rawValue: 1 << 2) }
    }
    public typealias ArrayLiteralElement = GraphicsContext.GradientOptions
    public typealias Element = GraphicsContext.GradientOptions
    public typealias RawValue = Swift.UInt32
  }
  public func resolve(_ shading: GraphicsContext.Shading) -> GraphicsContext.Shading { _abiUnimplemented("GraphicsContext: public func resolve(_ shading: GraphicsContext.Shading) -> GraphicsContext.Shading") }
  public func drawLayer(content: (inout GraphicsContext) throws -> Swift.Void) rethrows { _abiUnimplemented("GraphicsContext: public func drawLayer(content: (inout GraphicsContext) throws -> Swift.Void) rethrows") }
  public func fill(_ path: Path, with shading: GraphicsContext.Shading, style: FillStyle = FillStyle()) { _abiUnimplemented("GraphicsContext: public func fill(_ path: Path, with shading: GraphicsContext.Shading, style: FillStyle = FillStyle())") }
  public func stroke(_ path: Path, with shading: GraphicsContext.Shading, style: StrokeStyle) { _abiUnimplemented("GraphicsContext: public func stroke(_ path: Path, with shading: GraphicsContext.Shading, style: StrokeStyle)") }
  public func stroke(_ path: Path, with shading: GraphicsContext.Shading, lineWidth: CoreFoundation.CGFloat = 1) { _abiUnimplemented("GraphicsContext: public func stroke(_ path: Path, with shading: GraphicsContext.Shading, lineWidth: CoreFoundation.CGFloat = 1)") }
  public struct ResolvedImage {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
    public var size: CoreFoundation.CGSize {
      get { _abiUnimplemented("GraphicsContext: public var size: CoreFoundation.CGSize {") }
    }
    public let baseline: CoreFoundation.CGFloat
    public var shading: GraphicsContext.Shading?
  }
  public func resolve(_ image: Image) -> GraphicsContext.ResolvedImage { _abiUnimplemented("GraphicsContext: public func resolve(_ image: Image) -> GraphicsContext.ResolvedImage") }
  public func draw(_ image: GraphicsContext.ResolvedImage, in rect: CoreFoundation.CGRect, style: FillStyle = FillStyle()) { _abiUnimplemented("GraphicsContext: public func draw(_ image: GraphicsContext.ResolvedImage, in rect: CoreFoundation.CGRect, style: FillStyle = FillStyle())") }
  public func draw(_ image: GraphicsContext.ResolvedImage, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center) { _abiUnimplemented("GraphicsContext: public func draw(_ image: GraphicsContext.ResolvedImage, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center)") }
  public func draw(_ image: Image, in rect: CoreFoundation.CGRect, style: FillStyle = FillStyle()) { _abiUnimplemented("GraphicsContext: public func draw(_ image: Image, in rect: CoreFoundation.CGRect, style: FillStyle = FillStyle())") }
  public func draw(_ image: Image, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center) { _abiUnimplemented("GraphicsContext: public func draw(_ image: Image, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center)") }
  public struct ResolvedText {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
    public var shading: GraphicsContext.Shading
    public func measure(in size: CoreFoundation.CGSize) -> CoreFoundation.CGSize { _abiUnimplemented("GraphicsContext: public func measure(in size: CoreFoundation.CGSize) -> CoreFoundation.CGSize") }
    public func firstBaseline(in size: CoreFoundation.CGSize) -> CoreFoundation.CGFloat { _abiUnimplemented("GraphicsContext: public func firstBaseline(in size: CoreFoundation.CGSize) -> CoreFoundation.CGFloat") }
    public func lastBaseline(in size: CoreFoundation.CGSize) -> CoreFoundation.CGFloat { _abiUnimplemented("GraphicsContext: public func lastBaseline(in size: CoreFoundation.CGSize) -> CoreFoundation.CGFloat") }
  }
  public func resolve(_ text: Text) -> GraphicsContext.ResolvedText { _abiUnimplemented("GraphicsContext: public func resolve(_ text: Text) -> GraphicsContext.ResolvedText") }
  public func draw(_ text: GraphicsContext.ResolvedText, in rect: CoreFoundation.CGRect) { _abiUnimplemented("GraphicsContext: public func draw(_ text: GraphicsContext.ResolvedText, in rect: CoreFoundation.CGRect)") }
  public func draw(_ text: GraphicsContext.ResolvedText, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center) { _abiUnimplemented("GraphicsContext: public func draw(_ text: GraphicsContext.ResolvedText, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center)") }
  public func draw(_ text: Text, in rect: CoreFoundation.CGRect) { _abiUnimplemented("GraphicsContext: public func draw(_ text: Text, in rect: CoreFoundation.CGRect)") }
  public func draw(_ text: Text, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center) { _abiUnimplemented("GraphicsContext: public func draw(_ text: Text, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center)") }
  public struct ResolvedSymbol {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public var size: CoreFoundation.CGSize {
      get { _abiUnimplemented("GraphicsContext: public var size: CoreFoundation.CGSize {") }
    }
  }
  public func resolveSymbol<ID>(id: ID) -> GraphicsContext.ResolvedSymbol? where ID : Swift.Hashable { _abiUnimplemented("GraphicsContext: public func resolveSymbol<ID>(id: ID) -> GraphicsContext.ResolvedSymbol? where ID : Swift.Hashable") }
  public func draw(_ symbol: GraphicsContext.ResolvedSymbol, in rect: CoreFoundation.CGRect) { _abiUnimplemented("GraphicsContext: public func draw(_ symbol: GraphicsContext.ResolvedSymbol, in rect: CoreFoundation.CGRect)") }
  public func draw(_ symbol: GraphicsContext.ResolvedSymbol, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center) { _abiUnimplemented("GraphicsContext: public func draw(_ symbol: GraphicsContext.ResolvedSymbol, at point: CoreFoundation.CGPoint, anchor: UnitPoint = .center") }
  public func withCGContext(content: (CoreGraphics.CGContext) throws -> Swift.Void) rethrows { _abiUnimplemented("GraphicsContext: public func withCGContext(content: (CoreGraphics.CGContext) throws -> Swift.Void) rethrows") }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension GraphicsContext.BlendMode : Swift.Sendable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension GraphicsContext.ClipOptions : Swift.Sendable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension GraphicsContext.ShadowOptions : Swift.Sendable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension GraphicsContext.BlurOptions : Swift.Sendable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension GraphicsContext.FilterOptions : Swift.Sendable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension GraphicsContext.GradientOptions : Swift.Sendable {}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@frozen public struct Grid<Content> where Content : View {
  @usableFromInline
  internal var _tree: _VariadicView.Tree<GridLayout, Content>
  @inlinable public init(alignment: Alignment = .center, horizontalSpacing: CoreFoundation.CGFloat? = nil, verticalSpacing: CoreFoundation.CGFloat? = nil, @ViewBuilder content: () -> Content) {
        let root = GridLayout(alignment: alignment,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing)
        _tree = .init(root: root, content: content())
    }
  public static func _makeView(view: _GraphValue<Grid<Content>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public typealias Body = Swift.Never
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Grid : View {}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct GridItem {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public enum Size {
    case fixed(_: CoreFoundation.CGFloat)
    case flexible(minimum: CoreFoundation.CGFloat = 10, maximum: CoreFoundation.CGFloat = .infinity)
    case adaptive(minimum: CoreFoundation.CGFloat, maximum: CoreFoundation.CGFloat = .infinity)
  }
  public var size: GridItem.Size
  public var spacing: CoreFoundation.CGFloat?
  public var alignment: Alignment?
  public init(_ size: GridItem.Size = .flexible(), spacing: CoreFoundation.CGFloat? = nil, alignment: Alignment? = nil) { self.init(_abiTag: 0); _abiInertValue("GridItem") }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@frozen public struct GridLayout : _VariadicView.UnaryViewRoot {
  public var alignment: Alignment
  public var horizontalSpacing: CoreFoundation.CGFloat?
  public var verticalSpacing: CoreFoundation.CGFloat?
  @inlinable public init(alignment: Alignment = .center, horizontalSpacing: CoreFoundation.CGFloat? = nil, verticalSpacing: CoreFoundation.CGFloat? = nil) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }
  public static func _makeView(root: _GraphValue<GridLayout>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _ViewListOutputs) -> _ViewOutputs { _abiUnimplemented("GridLayout: public static func _makeView(root: _GraphValue<GridLayout>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _ViewLis") }
  public typealias Body = Swift.Never
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension GridLayout : Layout {
  public func makeCache(subviews: GridLayout.Subviews) -> GridLayout.Cache { _abiUnimplemented("GridLayout: public func makeCache(subviews: GridLayout.Subviews) -> GridLayout.Cache") }
  public func updateCache(_ cache: inout GridLayout.Cache, subviews: GridLayout.Subviews) { _abiUnimplemented("GridLayout: public func updateCache(_ cache: inout GridLayout.Cache, subviews: GridLayout.Subviews)") }
  public func spacing(subviews: GridLayout.Subviews, cache: inout GridLayout.Cache) -> ViewSpacing { _abiUnimplemented("GridLayout: public func spacing(subviews: GridLayout.Subviews, cache: inout GridLayout.Cache) -> ViewSpacing") }
  public func sizeThatFits(proposal: ProposedViewSize, subviews: GridLayout.Subviews, cache: inout GridLayout.Cache) -> CoreFoundation.CGSize { _abiUnimplemented("GridLayout: public func sizeThatFits(proposal: ProposedViewSize, subviews: GridLayout.Subviews, cache: inout GridLayout.Cache) -> Co") }
  public func placeSubviews(in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize, subviews: GridLayout.Subviews, cache: inout GridLayout.Cache) { _abiUnimplemented("GridLayout: public func placeSubviews(in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize, subviews: GridLayout.Subviews, c") }
  public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize, subviews: GridLayout.Subviews, cache: inout GridLayout.Cache) -> CoreFoundation.CGFloat? { _abiUnimplemented("GridLayout: public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSiz") }
  public func explicitAlignment(of guide: VerticalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize, subviews: GridLayout.Subviews, cache: inout GridLayout.Cache) -> CoreFoundation.CGFloat? { _abiUnimplemented("GridLayout: public func explicitAlignment(of guide: VerticalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize,") }
  public typealias AnimatableData = EmptyAnimatableData
}
extension GridLayout {
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public struct Cache {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension GridLayout : Swift.Sendable {}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@frozen public struct GridRow<Content> where Content : View {
  @usableFromInline
  internal var alignment: VerticalAlignment?
  @usableFromInline
  internal var content: Content
  @inlinable public init(alignment: VerticalAlignment? = nil, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }
  public static func _makeView(view: _GraphValue<GridRow<Content>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public static func _makeViewList(view: _GraphValue<GridRow<Content>>, inputs: _ViewListInputs) -> _ViewListOutputs { _ViewListOutputs(view: _darlingUnsupportedView(Self.self, inputs.viewInputs)) }
  public static func _viewListCount(inputs: _ViewListCountInputs) -> Swift.Int? { nil }
  public typealias Body = Swift.Never
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension GridRow : View {}

@available(iOS 13.0, tvOS 13.0, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
public struct GroupedListStyle : ListStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("GroupedListStyle") }
  @available(iOS, deprecated: 16.0, message: "Use listPadding instead.")
  public static func _sectionInset(_ sectionInset: EdgeInsets) -> GroupedListStyle { _abiUnimplemented("GroupedListStyle: public static func _sectionInset(_ sectionInset: EdgeInsets) -> GroupedListStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<GroupedListStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("GroupedListStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<GroupedListStyle, SelectionValue>>, inputs: _") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<GroupedListStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("GroupedListStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<GroupedListStyle, SelectionValue>>, input") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _HiddenModifier : ViewModifier {
  @inlinable public init() {}
  public static func _makeView(modifier: _GraphValue<_HiddenModifier>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _HiddenModifier : Swift.Sendable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public enum HorizontalEdge : Swift.Int8, Swift.CaseIterable, Swift.Codable {
  case leading
  case trailing
  @frozen public struct Set : Swift.OptionSet {
    public typealias Element = HorizontalEdge.Set
    public let rawValue: Swift.Int8
    public init(rawValue: Swift.Int8) { self.rawValue = rawValue }
    public static let leading: HorizontalEdge.Set = HorizontalEdge.Set(rawValue: 1 << 0)
    public static let trailing: HorizontalEdge.Set = HorizontalEdge.Set(rawValue: 1 << 1)
    public static let all: HorizontalEdge.Set = HorizontalEdge.Set(rawValue: 1 << 2)
    public init(_ edge: HorizontalEdge) { _abiUnimplemented("HorizontalEdge: public init(_ edge: HorizontalEdge)") }
    public typealias ArrayLiteralElement = HorizontalEdge.Set.Element
    public typealias RawValue = Swift.Int8
  }
  public init?(rawValue: Swift.Int8) { return nil }
  public typealias AllCases = [HorizontalEdge]
  public typealias RawValue = Swift.Int8
  public static var allCases: [HorizontalEdge] {
    get { _abiUnimplemented("HorizontalEdge: public static var allCases: [HorizontalEdge] {") }
  }
  public var rawValue: Swift.Int8 {
    get { _abiUnimplemented("HorizontalEdge: public var rawValue: Swift.Int8 {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension HorizontalEdge : Swift.Equatable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension HorizontalEdge : Swift.Hashable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension HorizontalEdge : Swift.RawRepresentable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension HorizontalEdge : Swift.Sendable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension HorizontalEdge.Set : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _HueRotationEffect : Swift.Equatable {
  public var angle: Angle
  @inlinable public init(angle: Angle) {
        self.angle = angle
    }
  public var animatableData: Angle.AnimatableData {
    get { _abiUnimplemented("_HueRotationEffect: public var animatableData: Angle.AnimatableData {") }
    set {}
  }
  public static func == (a: _HueRotationEffect, b: _HueRotationEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias AnimatableData = Angle.AnimatableData
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _HueRotationEffect : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _HueRotationEffect : ViewModifier {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _HueRotationEffect : Swift.Sendable {}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct IconOnlyLabelStyle : LabelStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("IconOnlyLabelStyle") }
  public func makeBody(configuration: IconOnlyLabelStyle.Configuration) -> some View { _abiUnimplemented("IconOnlyLabelStyle: public func makeBody(configuration: IconOnlyLabelStyle.Configuration) -> some View") }
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _IdentifiedViewProxy {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public var identifier: Swift.AnyHashable
  public var boundingRect: CoreFoundation.CGRect {
    get { _abiUnimplemented("_IdentifiedViewProxy: public var boundingRect: CoreFoundation.CGRect {") }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public enum _IdentifiedViewTree {
  case empty
  case proxy(_IdentifiedViewProxy)
  case array([_IdentifiedViewTree])
  public func forEach(_ body: (_IdentifiedViewProxy) -> Swift.Void) { _abiUnimplemented("_IdentifiedViewTree: public func forEach(_ body: (_IdentifiedViewProxy) -> Swift.Void)") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _IgnoredByLayoutEffect<Base> : GeometryEffect where Base : GeometryEffect {
  public var base: Base
  public static var _affectsLayout: Swift.Bool {
    get { _abiUnimplemented("_IgnoredByLayoutEffect: public static var _affectsLayout: Swift.Bool {") }
  }
  @inlinable public init(_ base: Base) {
        self.base = base
    }
  public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform { _abiUnimplemented("_IgnoredByLayoutEffect: public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform") }
  public var animatableData: Base.AnimatableData {
    get { _abiUnimplemented("_IgnoredByLayoutEffect: public var animatableData: Base.AnimatableData {") }
    set {}
  }
  public typealias AnimatableData = Base.AnimatableData
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _IgnoredByLayoutEffect : Swift.Equatable where Base : Swift.Equatable {
  public static func == (a: _IgnoredByLayoutEffect<Base>, b: _IgnoredByLayoutEffect<Base>) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}

@available(iOS 14.0, tvOS 14.0, watchOS 8.0, *)
@available(macOS, unavailable)
public protocol IndexViewStyle {
  associatedtype _Body : View
  @ViewBuilder func _makeBody(configuration: Self._Configuration) -> Self._Body
  typealias _Configuration = _IndexViewStyleConfiguration
}
@available(iOS 14.0, tvOS 14.0, watchOS 8.0, *)
@available(macOS, unavailable)
extension IndexViewStyle where Self == PageIndexViewStyle {
}

@available(iOS 14.0, tvOS 14.0, watchOS 8.0, *)
@available(macOS, unavailable)
public struct _IndexViewStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct InlinePickerStyle : PickerStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("InlinePickerStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<InlinePickerStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("InlinePickerStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<InlinePickerStyle, SelectionValue>>, inputs") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<InlinePickerStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("InlinePickerStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<InlinePickerStyle, SelectionValue>>, in") }
}

@available(iOS 14.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct InsetGroupedListStyle : ListStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("InsetGroupedListStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<InsetGroupedListStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("InsetGroupedListStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<InsetGroupedListStyle, SelectionValue>>, inpu") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<InsetGroupedListStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("InsetGroupedListStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<InsetGroupedListStyle, SelectionValue>>, ") }
}

@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct InsetListStyle : ListStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("InsetListStyle") }
  @available(macOS 12.0, *)
  @available(iOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public init(alternatesRowBackgrounds: Swift.Bool) { self.init(_abiTag: 0); _abiInertValue("InsetListStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<InsetListStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("InsetListStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<InsetListStyle, SelectionValue>>, inputs: _Vi") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<InsetListStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("InsetListStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<InsetListStyle, SelectionValue>>, inputs:") }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public struct _InsetViewModifier<Content> : ViewModifier where Content : View {
  @usableFromInline
  internal var content: Content
  @usableFromInline
  internal var properties: (regions: SafeAreaRegions, spacing: CoreFoundation.CGFloat?, edge: Edge, alignmentKey: AlignmentKey)
  @inlinable internal init(content: Content, edge: Edge, regions: SafeAreaRegions, spacing: CoreFoundation.CGFloat?, alignmentKey: AlignmentKey) {
        self.content = content
        properties = (regions, spacing, edge, alignmentKey)
    }
  public static func _makeView(modifier: _GraphValue<_InsetViewModifier<Content>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public typealias Body = Swift.Never
}

@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct KeyboardShortcut {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  @available(iOS 15.0, macOS 12.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public struct Localization {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public static let automatic: KeyboardShortcut.Localization = KeyboardShortcut.Localization(_abiTag: 1)
    public static let withoutMirroring: KeyboardShortcut.Localization = KeyboardShortcut.Localization(_abiTag: 2)
    public static let custom: KeyboardShortcut.Localization = KeyboardShortcut.Localization(_abiTag: 3)
  }
  public static let defaultAction: KeyboardShortcut = KeyboardShortcut(_abiTag: 4)
  public static let cancelAction: KeyboardShortcut = KeyboardShortcut(_abiTag: 5)
  public var key: KeyEquivalent
  public var modifiers: EventModifiers
  @available(iOS 15.0, macOS 12.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public var localization: KeyboardShortcut.Localization
  public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) { self.init(_abiTag: 0); _abiInertValue("KeyboardShortcut") }
  @available(iOS 15.0, macOS 12.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command, localization: KeyboardShortcut.Localization) { self.init(_abiTag: 0); _abiInertValue("KeyboardShortcut") }
}
@available(iOS 15.0, macOS 12.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension KeyboardShortcut : Swift.Hashable {
  public static func == (lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}

@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct KeyEquivalent {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public static let upArrow: KeyEquivalent = KeyEquivalent(_abiTag: 1)
  public static let downArrow: KeyEquivalent = KeyEquivalent(_abiTag: 2)
  public static let leftArrow: KeyEquivalent = KeyEquivalent(_abiTag: 3)
  public static let rightArrow: KeyEquivalent = KeyEquivalent(_abiTag: 4)
  public static let escape: KeyEquivalent = KeyEquivalent(_abiTag: 5)
  public static let delete: KeyEquivalent = KeyEquivalent(_abiTag: 6)
  public static let deleteForward: KeyEquivalent = KeyEquivalent(_abiTag: 7)
  public static let home: KeyEquivalent = KeyEquivalent(_abiTag: 8)
  public static let end: KeyEquivalent = KeyEquivalent(_abiTag: 9)
  public static let pageUp: KeyEquivalent = KeyEquivalent(_abiTag: 10)
  public static let pageDown: KeyEquivalent = KeyEquivalent(_abiTag: 11)
  public static let clear: KeyEquivalent = KeyEquivalent(_abiTag: 12)
  public static let tab: KeyEquivalent = KeyEquivalent(_abiTag: 13)
  public static let space: KeyEquivalent = KeyEquivalent(_abiTag: 14)
  public static let `return`: KeyEquivalent = KeyEquivalent(_abiTag: 15)
  public var character: Swift.Character
  public init(_ character: Swift.Character) { self.init(_abiTag: 0); _abiInertValue("KeyEquivalent") }
}
@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension KeyEquivalent : Swift.ExpressibleByExtendedGraphemeClusterLiteral {
  public init(extendedGraphemeClusterLiteral: Swift.Character) { self.init(_abiTag: 0); _abiInertValue("KeyEquivalent") }
  public typealias ExtendedGraphemeClusterLiteralType = Swift.Character
  public typealias UnicodeScalarLiteralType = Swift.Character
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct Label<Title, Icon> : View where Title : View, Icon : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) { self.init(_abiTag: 0); _abiInertValue("Label") }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("Label: @preconcurrency @MainActor public var body: some View {") }
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Label where Title == Text, Icon == Image {
  public init(_ titleKey: LocalizedStringKey, image name: Swift.String) { self.init(_abiTag: 0); _abiInertValue("Label") }
  public init(_ titleKey: LocalizedStringKey, systemImage name: Swift.String) { self.init(_abiTag: 0); _abiInertValue("Label") }
  @_disfavoredOverload public init<S>(_ title: S, image name: Swift.String) where S : Swift.StringProtocol { _abiUnimplemented("Label: @_disfavoredOverload public init<S>(_ title: S, image name: Swift.String) where S : Swift.StringProtocol") }
  @_disfavoredOverload public init<S>(_ title: S, systemImage name: Swift.String) where S : Swift.StringProtocol { _abiUnimplemented("Label: @_disfavoredOverload public init<S>(_ title: S, systemImage name: Swift.String) where S : Swift.StringProtocol") }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Label where Title == LabelStyleConfiguration.Title, Icon == LabelStyleConfiguration.Icon {
  public init(_ configuration: LabelStyleConfiguration) { self.init(_abiTag: 0); _abiInertValue("Label") }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct LabeledContent<Label, Content> {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension LabeledContent : View where Label : View, Content : View {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.init(_abiTag: 0); _abiInertValue("LabeledContent") }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("LabeledContent: @preconcurrency @MainActor public var body: some View {") }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension LabeledContent where Label == Text, Content : View {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("LabeledContent") }
  @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S : Swift.StringProtocol { _abiUnimplemented("LabeledContent: @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S : Swift.StringProtocol") }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension LabeledContent where Label == Text, Content == Text {
  public init<S>(_ titleKey: LocalizedStringKey, value: S) where S : Swift.StringProtocol { _abiUnimplemented("LabeledContent: public init<S>(_ titleKey: LocalizedStringKey, value: S) where S : Swift.StringProtocol") }
  @_disfavoredOverload public init<S1, S2>(_ title: S1, value: S2) where S1 : Swift.StringProtocol, S2 : Swift.StringProtocol { _abiUnimplemented("LabeledContent: @_disfavoredOverload public init<S1, S2>(_ title: S1, value: S2) where S1 : Swift.StringProtocol, S2 : Swift.StringProto") }
  public init<F>(_ titleKey: LocalizedStringKey, value: F.FormatInput, format: F) where F : Foundation.FormatStyle, F.FormatInput : Swift.Equatable, F.FormatOutput == Swift.String { _abiUnimplemented("LabeledContent: public init<F>(_ titleKey: LocalizedStringKey, value: F.FormatInput, format: F) where F : Foundation.FormatStyle, F.Form") }
  public init<S, F>(_ title: S, value: F.FormatInput, format: F) where S : Swift.StringProtocol, F : Foundation.FormatStyle, F.FormatInput : Swift.Equatable, F.FormatOutput == Swift.String { _abiUnimplemented("LabeledContent: public init<S, F>(_ title: S, value: F.FormatInput, format: F) where S : Swift.StringProtocol, F : Foundation.FormatStyl") }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension LabeledContent where Label == LabeledContentStyleConfiguration.Label, Content == LabeledContentStyleConfiguration.Content {
  public init(_ configuration: LabeledContentStyleConfiguration) { self.init(_abiTag: 0); _abiInertValue("LabeledContent") }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct LabeledContentStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public struct Label : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  public struct Content : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  public let label: LabeledContentStyleConfiguration.Label
  public let content: LabeledContentStyleConfiguration.Content
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct LabeledToolbarItemGroupContent<Content, Label> : View where Content : View, Label : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("LabeledToolbarItemGroupContent: @preconcurrency @MainActor public var body: some View {") }
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public protocol LabelStyle {
  associatedtype Body : View
  @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
  typealias Configuration = LabelStyleConfiguration
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LabelStyle where Self == IconOnlyLabelStyle {
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LabelStyle where Self == TitleOnlyLabelStyle {
}
@available(iOS 14.5, macOS 11.3, tvOS 14.5, watchOS 7.4, *)
extension LabelStyle where Self == TitleAndIconLabelStyle {
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LabelStyle where Self == DefaultLabelStyle {
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LabelStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public struct Title {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  public struct Icon {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  public var title: LabelStyleConfiguration.Title {
    get { _abiUnimplemented("LabelStyleConfiguration: public var title: LabelStyleConfiguration.Title {") }
  }
  public var icon: LabelStyleConfiguration.Icon {
    get { _abiUnimplemented("LabelStyleConfiguration: public var icon: LabelStyleConfiguration.Icon {") }
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LabelStyleConfiguration.Title : View {}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LabelStyleConfiguration.Icon : View {}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public protocol Layout : Animatable {
  static var layoutProperties: LayoutProperties { get }
  associatedtype Cache = Swift.Void
  typealias Subviews = LayoutSubviews
  func makeCache(subviews: Self.Subviews) -> Self.Cache
  func updateCache(_ cache: inout Self.Cache, subviews: Self.Subviews)
  func spacing(subviews: Self.Subviews, cache: inout Self.Cache) -> ViewSpacing
  func sizeThatFits(proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CoreFoundation.CGSize
  func placeSubviews(in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache)
  func explicitAlignment(of guide: HorizontalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CoreFoundation.CGFloat?
  func explicitAlignment(of guide: VerticalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CoreFoundation.CGFloat?
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Layout {
  public static var layoutProperties: LayoutProperties {
    get { _abiUnimplemented("Layout: public static var layoutProperties: LayoutProperties {") }
  }
  public func updateCache(_ cache: inout Self.Cache, subviews: Self.Subviews) { _abiUnimplemented("Layout: public func updateCache(_ cache: inout Self.Cache, subviews: Self.Subviews)") }
  public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CoreFoundation.CGFloat? { _abiUnimplemented("Layout: public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSiz") }
  public func explicitAlignment(of guide: VerticalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize, subviews: Self.Subviews, cache: inout Self.Cache) -> CoreFoundation.CGFloat? { _abiUnimplemented("Layout: public func explicitAlignment(of guide: VerticalAlignment, in bounds: CoreFoundation.CGRect, proposal: ProposedViewSize,") }
  public func spacing(subviews: Self.Subviews, cache: inout Self.Cache) -> ViewSpacing { _abiUnimplemented("Layout: public func spacing(subviews: Self.Subviews, cache: inout Self.Cache) -> ViewSpacing") }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Layout where Self.Cache == () {
  public func makeCache(subviews: Self.Subviews) -> Self.Cache { _abiUnimplemented("Layout: public func makeCache(subviews: Self.Subviews) -> Self.Cache") }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Layout {
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public enum LayoutDirection : Swift.Hashable, Swift.CaseIterable {
  case leftToRight
  case rightToLeft
  public static func == (a: LayoutDirection, b: LayoutDirection) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public typealias AllCases = [LayoutDirection]
  public static var allCases: [LayoutDirection] {
    get { _abiUnimplemented("LayoutDirection: public static var allCases: [LayoutDirection] {") }
  }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
extension LayoutDirection {
  @available(iOS 14.0, tvOS 14.0, *)
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  public init?(_ uiLayoutDirection: UIKit.UITraitEnvironmentLayoutDirection) { return nil }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal struct LayoutPriorityTraitKey : _ViewTraitKey {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @inlinable internal static var defaultValue: Swift.Double {
    get { 0.0 }
  }
  @usableFromInline
  internal typealias Value = Swift.Double
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct LayoutProperties {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("LayoutProperties") }
  public var stackOrientation: Axis?
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@frozen public struct _LayoutRoot<L> : _VariadicView.UnaryViewRoot where L : Layout {
  @usableFromInline
  internal var layout: L
  @inlinable internal init(_ layout: L) { self.layout = layout }
  public static func _makeView(root: _GraphValue<_LayoutRoot<L>>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _ViewListOutputs) -> _ViewOutputs { _abiUnimplemented("_LayoutRoot: public static func _makeView(root: _GraphValue<_LayoutRoot<L>>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _Vie") }
  public typealias Body = Swift.Never
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct LayoutSubview : Swift.Equatable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public func _trait<K>(key: K.Type) -> K.Value where K : _ViewTraitKey { _abiUnimplemented("LayoutSubview: public func _trait<K>(key: K.Type) -> K.Value where K : _ViewTraitKey") }
  public subscript<K>(key: K.Type) -> K.Value where K : LayoutValueKey {
    get { _abiUnimplemented("LayoutSubview: public subscript<K>(key: K.Type) -> K.Value where K : LayoutValueKey {") }
  }
  public var priority: Swift.Double {
    get { _abiUnimplemented("LayoutSubview: public var priority: Swift.Double {") }
  }
  public func sizeThatFits(_ proposal: ProposedViewSize) -> CoreFoundation.CGSize { _abiUnimplemented("LayoutSubview: public func sizeThatFits(_ proposal: ProposedViewSize) -> CoreFoundation.CGSize") }
  public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions { _abiUnimplemented("LayoutSubview: public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions") }
  public var spacing: ViewSpacing {
    get { _abiUnimplemented("LayoutSubview: public var spacing: ViewSpacing {") }
  }
  public func place(at position: CoreFoundation.CGPoint, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) { _abiUnimplemented("LayoutSubview: public func place(at position: CoreFoundation.CGPoint, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize)") }
  public static func == (a: LayoutSubview, b: LayoutSubview) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct LayoutSubviews : Swift.Equatable, Swift.RandomAccessCollection {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public typealias SubSequence = LayoutSubviews
  public typealias Element = LayoutSubview
  public typealias Index = Swift.Int
  public var layoutDirection: LayoutDirection
  public var startIndex: Swift.Int {
    get { _abiUnimplemented("LayoutSubviews: public var startIndex: Swift.Int {") }
  }
  public var endIndex: Swift.Int {
    get { _abiUnimplemented("LayoutSubviews: public var endIndex: Swift.Int {") }
  }
  public subscript(index: Swift.Int) -> LayoutSubviews.Element {
    get { _abiUnimplemented("LayoutSubviews: public subscript(index: Swift.Int) -> LayoutSubviews.Element {") }
  }
  public subscript(bounds: Swift.Range<Swift.Int>) -> LayoutSubviews {
    get { _abiUnimplemented("LayoutSubviews: public subscript(bounds: Swift.Range<Swift.Int>) -> LayoutSubviews {") }
  }
  public subscript<S>(indices: S) -> LayoutSubviews where S : Swift.Sequence, S.Element == Swift.Int {
    get { _abiUnimplemented("LayoutSubviews: public subscript<S>(indices: S) -> LayoutSubviews where S : Swift.Sequence, S.El") }
  }
  public static func == (lhs: LayoutSubviews, rhs: LayoutSubviews) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
  public typealias Indices = Swift.Range<LayoutSubviews.Index>
  public typealias Iterator = Swift.IndexingIterator<LayoutSubviews>
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _LayoutTraits : Swift.Equatable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static func == (a: _LayoutTraits, b: _LayoutTraits) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _LayoutTraits : Swift.CustomStringConvertible {
  public var description: Swift.String {
    get { _abiUnimplemented("_LayoutTraits: public var description: Swift.String {") }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public protocol LayoutValueKey {
  associatedtype Value
  static var defaultValue: Self.Value { get }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LazyHStack<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(alignment: VerticalAlignment = .center, spacing: CoreFoundation.CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("LazyHStack") }
  public static func _makeView(view: _GraphValue<LazyHStack<Content>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public typealias Body = Swift.Never
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LazyVGrid<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CoreFoundation.CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("LazyVGrid") }
  public static func _makeView(view: _GraphValue<LazyVGrid<Content>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public typealias Body = Swift.Never
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LazyVStack<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(alignment: HorizontalAlignment = .center, spacing: CoreFoundation.CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("LazyVStack") }
  public static func _makeView(view: _GraphValue<LazyVStack<Content>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct LinearGradient : ShapeStyle, View {
  internal var gradient: Gradient
  internal var startPoint: UnitPoint
  internal var endPoint: UnitPoint
  public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) { _abiUnimplemented("LinearGradient: public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint)") }
  public typealias Body = _ShapeView<Rectangle, LinearGradient>
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LinearProgressViewStyle : ProgressViewStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("LinearProgressViewStyle") }
  @available(iOS, introduced: 14.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  @available(macOS, introduced: 11.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  @available(tvOS, introduced: 14.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  @available(watchOS, introduced: 7.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  public init(tint: Color) { self.init(_abiTag: 0); _abiInertValue("LinearProgressViewStyle") }
  public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View { _abiUnimplemented("LinearProgressViewStyle: public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View") }
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal struct ListRowBackgroundTraitKey : _ViewTraitKey {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @inlinable internal static var defaultValue: AnyView? {
    get { nil }
  }
  @usableFromInline
  internal typealias Value = AnyView?
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal struct ListRowInsetsTraitKey : _ViewTraitKey {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @inlinable internal static var defaultValue: EdgeInsets? {
    get { nil }
  }
  @usableFromInline
  internal typealias Value = EdgeInsets?
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol ListStyle {
  static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<Self, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable
  static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<Self, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ListStyle where Self == DefaultListStyle {
}
@available(iOS 14.0, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension ListStyle where Self == SidebarListStyle {
}
@available(iOS 14.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension ListStyle where Self == InsetGroupedListStyle {
}
@available(iOS 13.0, tvOS 13.0, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
extension ListStyle where Self == GroupedListStyle {
}
@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension ListStyle where Self == InsetListStyle {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ListStyle where Self == PlainListStyle {
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _ListValue<Style, SelectionValue> where Style : ListStyle, SelectionValue : Swift.Hashable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _MapGesture<Content, Value> where Content : Gesture {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static func _makeGesture(gesture: _GraphValue<_MapGesture<Content, Value>>, inputs: _GestureInputs) -> _GestureOutputs<Value> { _abiUnimplemented("_MapGesture: public static func _makeGesture(gesture: _GraphValue<_MapGesture<Content, Value>>, inputs: _GestureInputs) -> _GestureOu") }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _MapGesture : Gesture {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public struct _MaskAlignmentEffect<Mask> : ViewModifier where Mask : View {
  public var alignment: Alignment
  public var mask: Mask
  @inlinable public init(alignment: Alignment, mask: Mask) {
        self.mask = mask
        self.alignment = alignment
    }
  public static func _makeView(modifier: _GraphValue<_MaskAlignmentEffect<Mask>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _MaskEffect<Mask> : ViewModifier where Mask : View {
  public var mask: Mask
  @inlinable public init(mask: Mask) {
        self.mask = mask
    }
  public static func _makeView(modifier: _GraphValue<_MaskEffect<Mask>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _MaskEffect : Swift.Equatable where Mask : Swift.Equatable {
  public static func == (a: _MaskEffect<Mask>, b: _MaskEffect<Mask>) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@frozen public struct _MatchedGeometryEffect<ID> where ID : Swift.Hashable {
  public var id: ID
  public var namespace: Namespace.ID
  public var args: (properties: MatchedGeometryProperties, anchor: UnitPoint, isSource: Swift.Bool)
  @inlinable public init(id: ID, namespace: Namespace.ID, properties: MatchedGeometryProperties, anchor: UnitPoint, isSource: Swift.Bool) {
        (self.id, self.namespace) = (id, namespace)
        args = (properties: properties, anchor: anchor, isSource: isSource)
    }
  public static func _makeView(modifier: _GraphValue<_MatchedGeometryEffect<ID>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public typealias Body = Swift.Never
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _MatchedGeometryEffect : ViewModifier {}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@frozen public struct MatchedGeometryProperties : Swift.OptionSet {
  public let rawValue: Swift.UInt32
  @inlinable public init(rawValue: Swift.UInt32) { self.rawValue = rawValue }
  public static let position: MatchedGeometryProperties = MatchedGeometryProperties(rawValue: 1 << 0)
  public static let size: MatchedGeometryProperties = MatchedGeometryProperties(rawValue: 1 << 1)
  public static let frame: MatchedGeometryProperties = MatchedGeometryProperties(rawValue: 1 << 2)
  public typealias ArrayLiteralElement = MatchedGeometryProperties
  public typealias Element = MatchedGeometryProperties
  public typealias RawValue = Swift.UInt32
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension MatchedGeometryProperties : Swift.Sendable {}

@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct Menu<Label, Content> : View where Label : View, Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("Menu: @preconcurrency @MainActor public var body: some View {") }
  }
}
@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Menu {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) { self.init(_abiTag: 0); _abiInertValue("Menu") }
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) where Label == Text { self.init(_abiTag: 0); _abiInertValue("Menu") }
  @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content) where Label == Text, S : Swift.StringProtocol { _abiUnimplemented("Menu: @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content) where Label == Text, S : Swift.Stri") }
}
@available(iOS 15.0, macOS 12.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Menu {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, primaryAction: @escaping () -> Swift.Void) { self.init(_abiTag: 0); _abiInertValue("Menu") }
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Swift.Void) where Label == Text { self.init(_abiTag: 0); _abiInertValue("Menu") }
  @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Swift.Void) where Label == Text, S : Swift.StringProtocol { _abiUnimplemented("Menu: @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Swif") }
}
@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Menu where Label == MenuStyleConfiguration.Label, Content == MenuStyleConfiguration.Content {
  public init(_ configuration: MenuStyleConfiguration) { self.init(_abiTag: 0); _abiInertValue("Menu") }
}

@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct MenuPickerStyle : PickerStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("MenuPickerStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<MenuPickerStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("MenuPickerStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<MenuPickerStyle, SelectionValue>>, inputs: ") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<MenuPickerStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("MenuPickerStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<MenuPickerStyle, SelectionValue>>, inpu") }
}

@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct MenuStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public struct Label : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  public struct Content : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
}

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@available(macOS, unavailable)
public struct NavigationBarItem {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public enum TitleDisplayMode {
    case automatic
    case inline
    @available(watchOS 8.0, *)
    @available(tvOS, unavailable)
    case large
    public static func == (a: NavigationBarItem.TitleDisplayMode, b: NavigationBarItem.TitleDisplayMode) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
}
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@available(macOS, unavailable)
extension NavigationBarItem.TitleDisplayMode : Swift.Equatable {}
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@available(macOS, unavailable)
extension NavigationBarItem.TitleDisplayMode : Swift.Hashable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct NavigationLink<Label, Destination> : View where Label : View, Destination : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("NavigationLink: @preconcurrency @MainActor public var body: some View {") }
  }
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  @available(macOS, introduced: 10.15, deprecated: 100000.0, message: "Pass a closure as the destination")
  @available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  @available(watchOS, introduced: 6.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  public init(destination: Destination, @ViewBuilder label: () -> Label) { self.init(_abiTag: 0); _abiInertValue("NavigationLink") }
  @available(iOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(value:label:) inside a NavigationStack or NavigationSplitView")
  @available(macOS, introduced: 10.15, deprecated: 13.0, message: "use NavigationLink(value:label:) inside a NavigationStack or NavigationSplitView")
  @available(tvOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(value:label:) inside a NavigationStack or NavigationSplitView")
  @available(watchOS, introduced: 6.0, deprecated: 9.0, message: "use NavigationLink(value:label:) inside a NavigationStack or NavigationSplitView")
  public init(destination: Destination, isActive: Binding<Swift.Bool>, @ViewBuilder label: () -> Label) { self.init(_abiTag: 0); _abiInertValue("NavigationLink") }
  @available(iOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(value:label:) inside a List within a NavigationStack or NavigationSplitView")
  @available(macOS, introduced: 10.15, deprecated: 13.0, message: "use NavigationLink(value:label:) inside a List within a NavigationStack or NavigationSplitView")
  @available(tvOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(value:label:) inside a List within a NavigationStack or NavigationSplitView")
  @available(watchOS, introduced: 6.0, deprecated: 9.0, message: "use NavigationLink(value:label:) inside a List within a NavigationStack or NavigationSplitView")
  public init<V>(destination: Destination, tag: V, selection: Binding<V?>, @ViewBuilder label: () -> Label) where V : Swift.Hashable { _abiUnimplemented("NavigationLink: public init<V>(destination: Destination, tag: V, selection: Binding<V?>, @ViewBuilder label: () -> Label) where V : Swif") }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension NavigationLink where Destination == Swift.Never {
  public init<P>(value: P?, @ViewBuilder label: () -> Label) where P : Swift.Hashable { _abiUnimplemented("NavigationLink: public init<P>(value: P?, @ViewBuilder label: () -> Label) where P : Swift.Hashable") }
  public init<P>(_ titleKey: LocalizedStringKey, value: P?) where Label == Text, P : Swift.Hashable { _abiUnimplemented("NavigationLink: public init<P>(_ titleKey: LocalizedStringKey, value: P?) where Label == Text, P : Swift.Hashable") }
  @_disfavoredOverload public init<S, P>(_ title: S, value: P?) where Label == Text, S : Swift.StringProtocol, P : Swift.Hashable { _abiUnimplemented("NavigationLink: @_disfavoredOverload public init<S, P>(_ title: S, value: P?) where Label == Text, S : Swift.StringProtocol, P : Swift.H") }
  public init<P>(value: P?, @ViewBuilder label: () -> Label) where P : Swift.Decodable, P : Swift.Encodable, P : Swift.Hashable { _abiUnimplemented("NavigationLink: public init<P>(value: P?, @ViewBuilder label: () -> Label) where P : Swift.Decodable, P : Swift.Encodable, P : Swift.Has") }
  public init<P>(_ titleKey: LocalizedStringKey, value: P?) where Label == Text, P : Swift.Decodable, P : Swift.Encodable, P : Swift.Hashable { _abiUnimplemented("NavigationLink: public init<P>(_ titleKey: LocalizedStringKey, value: P?) where Label == Text, P : Swift.Decodable, P : Swift.Encodable,") }
  @_disfavoredOverload public init<S, P>(_ title: S, value: P?) where Label == Text, S : Swift.StringProtocol, P : Swift.Decodable, P : Swift.Encodable, P : Swift.Hashable { _abiUnimplemented("NavigationLink: @_disfavoredOverload public init<S, P>(_ title: S, value: P?) where Label == Text, S : Swift.StringProtocol, P : Swift.D") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension NavigationLink where Label == Text {
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  @available(macOS, introduced: 10.15, deprecated: 100000.0, message: "Pass a closure as the destination")
  @available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  @available(watchOS, introduced: 6.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  public init(_ titleKey: LocalizedStringKey, destination: Destination) { self.init(_abiTag: 0); _abiInertValue("NavigationLink") }
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  @available(macOS, introduced: 10.15, deprecated: 100000.0, message: "Pass a closure as the destination")
  @available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  @available(watchOS, introduced: 6.0, deprecated: 100000.0, message: "Pass a closure as the destination")
  @_disfavoredOverload public init<S>(_ title: S, destination: Destination) where S : Swift.StringProtocol { _abiUnimplemented("NavigationLink: @_disfavoredOverload public init<S>(_ title: S, destination: Destination) where S : Swift.StringProtocol") }
  @available(iOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(_:value:) inside a NavigationStack or NavigationSplitView")
  @available(macOS, introduced: 10.15, deprecated: 13.0, message: "use NavigationLink(_:value:) inside a NavigationStack or NavigationSplitView")
  @available(tvOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(_:value:) inside a NavigationStack or NavigationSplitView")
  @available(watchOS, introduced: 6.0, deprecated: 9.0, message: "use NavigationLink(_:value:) inside a NavigationStack or NavigationSplitView")
  public init(_ titleKey: LocalizedStringKey, destination: Destination, isActive: Binding<Swift.Bool>) { self.init(_abiTag: 0); _abiInertValue("NavigationLink") }
  @available(iOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(_:value:) inside a NavigationStack or NavigationSplitView")
  @available(macOS, introduced: 10.15, deprecated: 13.0, message: "use NavigationLink(_:value:) inside a NavigationStack or NavigationSplitView")
  @available(tvOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(_:value:) inside a NavigationStack or NavigationSplitView")
  @available(watchOS, introduced: 6.0, deprecated: 9.0, message: "use NavigationLink(_:value:) inside a NavigationStack or NavigationSplitView")
  @_disfavoredOverload public init<S>(_ title: S, destination: Destination, isActive: Binding<Swift.Bool>) where S : Swift.StringProtocol { _abiUnimplemented("NavigationLink: @_disfavoredOverload public init<S>(_ title: S, destination: Destination, isActive: Binding<Swift.Bool>) where S : Swift") }
  @available(iOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(_:value:) inside a List within a NavigationStack or NavigationSplitView")
  @available(macOS, introduced: 10.15, deprecated: 13.0, message: "use NavigationLink(_:value:) inside a List within a NavigationStack or NavigationSplitView")
  @available(tvOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(_:value:) inside a List within a NavigationStack or NavigationSplitView")
  @available(watchOS, introduced: 6.0, deprecated: 9.0, message: "use NavigationLink(_:value:) inside a List within a NavigationStack or NavigationSplitView")
  public init<V>(_ titleKey: LocalizedStringKey, destination: Destination, tag: V, selection: Binding<V?>) where V : Swift.Hashable { _abiUnimplemented("NavigationLink: public init<V>(_ titleKey: LocalizedStringKey, destination: Destination, tag: V, selection: Binding<V?>) where V : Swift") }
  @available(iOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(_:value:) inside a List within a NavigationStack or NavigationSplitView")
  @available(macOS, introduced: 10.15, deprecated: 13.0, message: "use NavigationLink(_:value:) inside a List within a NavigationStack or NavigationSplitView")
  @available(tvOS, introduced: 13.0, deprecated: 16.0, message: "use NavigationLink(_:value:) inside a List within a NavigationStack or NavigationSplitView")
  @available(watchOS, introduced: 6.0, deprecated: 9.0, message: "use NavigationLink(_:value:) inside a List within a NavigationStack or NavigationSplitView")
  @_disfavoredOverload public init<S, V>(_ title: S, destination: Destination, tag: V, selection: Binding<V?>) where S : Swift.StringProtocol, V : Swift.Hashable { _abiUnimplemented("NavigationLink: @_disfavoredOverload public init<S, V>(_ title: S, destination: Destination, tag: V, selection: Binding<V?>) where S : S") }
}

@available(iOS 16.0, tvOS 16.0, watchOS 9.0, *)
@available(macOS, unavailable)
public struct NavigationLinkPickerStyle : PickerStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("NavigationLinkPickerStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<NavigationLinkPickerStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("NavigationLinkPickerStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<NavigationLinkPickerStyle, SelectionValue>>") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<NavigationLinkPickerStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("NavigationLinkPickerStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<NavigationLinkPickerStyle, SelectionVal") }
}

@available(iOS, introduced: 13.0, deprecated: 100000.0, message: "use NavigationStack or NavigationSplitView instead")
@available(macOS, introduced: 10.15, deprecated: 100000.0, message: "use NavigationStack or NavigationSplitView instead")
@available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "use NavigationStack or NavigationSplitView instead")
@available(watchOS, introduced: 7.0, deprecated: 100000.0, message: "use NavigationStack or NavigationSplitView instead")
public struct NavigationView<Content> : View where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(@ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("NavigationView") }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _OffsetEffect : GeometryEffect, Swift.Equatable {
  public var offset: CoreFoundation.CGSize
  @inlinable public init(offset: CoreFoundation.CGSize) {
        self.offset = offset
    }
  public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform { _abiUnimplemented("_OffsetEffect: public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform") }
  public var animatableData: CoreFoundation.CGSize.AnimatableData {
    get { _abiUnimplemented("_OffsetEffect: public var animatableData: CoreFoundation.CGSize.AnimatableData {") }
    set {}
  }
  public static func _makeView(modifier: _GraphValue<_OffsetEffect>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public static func == (a: _OffsetEffect, b: _OffsetEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias AnimatableData = CoreFoundation.CGSize.AnimatableData
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _OffsetEffect : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal struct OnDeleteTraitKey : _ViewTraitKey {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @inlinable internal static var defaultValue: Swift.Optional<(Foundation.IndexSet) -> Swift.Void> {
    get { nil }
  }
  @usableFromInline
  internal typealias Value = Swift.Optional<(Foundation.IndexSet) -> Swift.Void>
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal struct OnMoveTraitKey : _ViewTraitKey {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @inlinable internal static var defaultValue: Swift.Optional<(Foundation.IndexSet, Swift.Int) -> Swift.Void> {
    get { nil }
  }
  @usableFromInline
  internal typealias Value = Swift.Optional<(Foundation.IndexSet, Swift.Int) -> Swift.Void>
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _OpacityEffect : Swift.Equatable {
  public var opacity: Swift.Double
  @inlinable public init(opacity: Swift.Double) {
        self.opacity = opacity
    }
  public var animatableData: Swift.Double {
    get { _abiUnimplemented("_OpacityEffect: public var animatableData: Swift.Double {") }
    set {}
  }
  public static func _makeView(modifier: _GraphValue<_OpacityEffect>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public static func == (a: _OpacityEffect, b: _OpacityEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias AnimatableData = Swift.Double
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _OpacityEffect : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _OpacityEffect : ViewModifier {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _OpacityEffect : Swift.Sendable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public struct _OpacityShapeStyle<Style> : ShapeStyle where Style : ShapeStyle {
  public var style: Style
  public var opacity: Swift.Float
  @inlinable public init(style: Style, opacity: Swift.Float) {
        self.style = style
        self.opacity = opacity
    }
  public func _apply(to shape: inout _ShapeStyle_Shape) { _abiUnimplemented("_OpacityShapeStyle: public func _apply(to shape: inout _ShapeStyle_Shape)") }
  public static func _apply(to type: inout _ShapeStyle_ShapeType) { _abiUnimplemented("_OpacityShapeStyle: public static func _apply(to type: inout _ShapeStyle_ShapeType)") }
}

@available(iOS 14.0, tvOS 14.0, watchOS 8.0, *)
@available(macOS, unavailable)
public struct PageIndexViewStyle : IndexViewStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public struct BackgroundDisplayMode {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public static let automatic: PageIndexViewStyle.BackgroundDisplayMode = PageIndexViewStyle.BackgroundDisplayMode(_abiTag: 1)
    @available(watchOS, unavailable)
    public static let interactive: PageIndexViewStyle.BackgroundDisplayMode = PageIndexViewStyle.BackgroundDisplayMode(_abiTag: 2)
    @available(watchOS, unavailable)
    public static let always: PageIndexViewStyle.BackgroundDisplayMode = PageIndexViewStyle.BackgroundDisplayMode(_abiTag: 3)
    public static let never: PageIndexViewStyle.BackgroundDisplayMode = PageIndexViewStyle.BackgroundDisplayMode(_abiTag: 4)
  }
  public init(backgroundDisplayMode: PageIndexViewStyle.BackgroundDisplayMode = .automatic) { self.init(_abiTag: 0); _abiInertValue("PageIndexViewStyle") }
  public func _makeBody(configuration: PageIndexViewStyle._Configuration) -> some View { _abiUnimplemented("PageIndexViewStyle: public func _makeBody(configuration: PageIndexViewStyle._Configuration) -> some View") }
  
}

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, *)
@available(macOS, unavailable)
public struct PageTabViewStyle : TabViewStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public struct IndexDisplayMode {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public static let automatic: PageTabViewStyle.IndexDisplayMode = PageTabViewStyle.IndexDisplayMode(_abiTag: 1)
    @available(watchOS 8.0, *)
    public static let always: PageTabViewStyle.IndexDisplayMode = PageTabViewStyle.IndexDisplayMode(_abiTag: 2)
    @available(watchOS 8.0, *)
    public static let never: PageTabViewStyle.IndexDisplayMode = PageTabViewStyle.IndexDisplayMode(_abiTag: 3)
  }
  public init(indexDisplayMode: PageTabViewStyle.IndexDisplayMode = .automatic) { self.init(_abiTag: 0); _abiInertValue("PageTabViewStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_TabViewValue<PageTabViewStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("PageTabViewStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_TabViewValue<PageTabViewStyle, SelectionValue>>, inputs") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_TabViewValue<PageTabViewStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("PageTabViewStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_TabViewValue<PageTabViewStyle, SelectionValue>>, in") }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct PeriodicTimelineSchedule : TimelineSchedule {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public struct Entries : Swift.Sequence, Swift.IteratorProtocol {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public mutating func next() -> Foundation.Date? { _abiUnimplemented("PeriodicTimelineSchedule: public mutating func next() -> Foundation.Date?") }
    public typealias Element = Foundation.Date
    public typealias Iterator = PeriodicTimelineSchedule.Entries
  }
  public init(from startDate: Foundation.Date, by interval: Foundation.TimeInterval) { self.init(_abiTag: 0); _abiInertValue("PeriodicTimelineSchedule") }
  public func entries(from startDate: Foundation.Date, mode: TimelineScheduleMode) -> PeriodicTimelineSchedule.Entries { _abiUnimplemented("PeriodicTimelineSchedule: public func entries(from startDate: Foundation.Date, mode: TimelineScheduleMode) -> PeriodicTimelineSchedule.Entries") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Picker<Label, SelectionValue, Content> : View where Label : View, SelectionValue : Swift.Hashable, Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("Picker: @preconcurrency @MainActor public var body: some View {") }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Picker {
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init<C>(sources: C, selection: Swift.KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) where C : Swift.RandomAccessCollection { _abiUnimplemented("Picker: public init<C>(sources: C, selection: Swift.KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Con") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Picker where Label == Text {
  public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("Picker") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init<C>(_ titleKey: LocalizedStringKey, sources: C, selection: Swift.KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content) where C : Swift.RandomAccessCollection { _abiUnimplemented("Picker: public init<C>(_ titleKey: LocalizedStringKey, sources: C, selection: Swift.KeyPath<C.Element, Binding<SelectionValue>>,") }
  @_disfavoredOverload public init<S>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) where S : Swift.StringProtocol { _abiUnimplemented("Picker: @_disfavoredOverload public init<S>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content)") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  @_disfavoredOverload public init<C, S>(_ title: S, sources: C, selection: Swift.KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content) where C : Swift.RandomAccessCollection, S : Swift.StringProtocol { _abiUnimplemented("Picker: @_disfavoredOverload public init<C, S>(_ title: S, sources: C, selection: Swift.KeyPath<C.Element, Binding<SelectionValu") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Picker {
  @available(iOS, deprecated: 100000.0, renamed: "Picker(selection:content:label:)")
  @available(macOS, deprecated: 100000.0, renamed: "Picker(selection:content:label:)")
  @available(tvOS, deprecated: 100000.0, renamed: "Picker(selection:content:label:)")
  @available(watchOS, deprecated: 100000.0, renamed: "Picker(selection:content:label:)")
  public init(selection: Binding<SelectionValue>, label: Label, @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("Picker") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol PickerStyle {
  static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<Self, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable
  static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<Self, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable
}
@available(iOS 16.0, tvOS 16.0, watchOS 9.0, *)
@available(macOS, unavailable)
extension PickerStyle where Self == NavigationLinkPickerStyle {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
@available(watchOS, unavailable)
extension PickerStyle where Self == SegmentedPickerStyle {
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension PickerStyle where Self == InlinePickerStyle {
}
@available(iOS 13.0, watchOS 6.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
extension PickerStyle where Self == WheelPickerStyle {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension PickerStyle where Self == DefaultPickerStyle {
}
@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension PickerStyle where Self == MenuPickerStyle {
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _PickerValue<Style, SelectionValue> where Style : PickerStyle, SelectionValue : Swift.Hashable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct PinnedScrollableViews : Swift.OptionSet {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public let rawValue: Swift.UInt32
  public init(rawValue: Swift.UInt32) { self.rawValue = rawValue }
  public static let sectionHeaders: PinnedScrollableViews = PinnedScrollableViews(rawValue: 1 << 0)
  public static let sectionFooters: PinnedScrollableViews = PinnedScrollableViews(rawValue: 1 << 1)
  public typealias ArrayLiteralElement = PinnedScrollableViews
  public typealias Element = PinnedScrollableViews
  public typealias RawValue = Swift.UInt32
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct PlainButtonStyle : PrimitiveButtonStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("PlainButtonStyle") }
  public func makeBody(configuration: PlainButtonStyle.Configuration) -> some View { _abiUnimplemented("PlainButtonStyle: public func makeBody(configuration: PlainButtonStyle.Configuration) -> some View") }
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct PlainListStyle : ListStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("PlainListStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<PlainListStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("PlainListStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<PlainListStyle, SelectionValue>>, inputs: _Vi") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<PlainListStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("PlainListStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<PlainListStyle, SelectionValue>>, inputs:") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _PositionLayout {
  public var position: CoreFoundation.CGPoint
  @inlinable public init(position: CoreFoundation.CGPoint) {
        self.position = position
    }
  public typealias AnimatableData = EmptyAnimatableData
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _PositionLayout : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _PositionLayout : ViewModifier {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _PositionLayout : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _PreferenceActionModifier<Key> : ViewModifier where Key : PreferenceKey, Key.Value : Swift.Equatable {
  public var action: (Key.Value) -> Swift.Void
  @inlinable public init(action: @escaping (Key.Value) -> Swift.Void) {
        self.action = action
    }
  public static func _makeView(modifier: _GraphValue<_PreferenceActionModifier<Key>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol PreferenceKey {
  associatedtype Value
  static var defaultValue: Self.Value { get }
  static func reduce(value: inout Self.Value, nextValue: () -> Self.Value)
  static var _includesRemovedValues: Swift.Bool { get }
  static var _isReadableByHost: Swift.Bool { get }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension PreferenceKey {
  @inlinable public static func _delay<T>(_ transform: @escaping (_PreferenceValue<Self>) -> T) -> some View where T : View {
        return _DelayedPreferenceView(transform: transform)
    }
  
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension PreferenceKey where Self.Value : Swift.ExpressibleByNilLiteral {
  public static var defaultValue: Self.Value {
    get { _abiUnimplemented("PreferenceKey: public static var defaultValue: Self.Value {") }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension PreferenceKey {
  public static var _includesRemovedValues: Swift.Bool {
    get { _abiUnimplemented("PreferenceKey: public static var _includesRemovedValues: Swift.Bool {") }
  }
  public static var _isReadableByHost: Swift.Bool {
    get { _abiUnimplemented("PreferenceKey: public static var _isReadableByHost: Swift.Bool {") }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _PreferenceValue<Key> where Key : PreferenceKey {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _PreferenceWritingModifier<Key> : ViewModifier where Key : PreferenceKey {
  public var value: Key.Value
  public typealias Body = Swift.Never
  @inlinable public init(key: Key.Type = Key.self, value: Key.Value) {
        self.value = value
    }
  public static func _makeView(modifier: _GraphValue<_PreferenceWritingModifier<Key>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public static func _makeViewList(modifier: _GraphValue<_PreferenceWritingModifier<Key>>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs { body(_Graph(), inputs) }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _PreferenceWritingModifier : _SceneModifier {
  public static func _makeScene(modifier: _GraphValue<_PreferenceWritingModifier<Key>>, inputs: _SceneInputs, body: @escaping (_Graph, _SceneInputs) -> _SceneOutputs) -> _SceneOutputs { _abiUnimplemented("_PreferenceWritingModifier: public static func _makeScene(modifier: _GraphValue<_PreferenceWritingModifier<Key>>, inputs: _SceneInputs, body: @escap") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _PreferenceWritingModifier : Swift.Equatable where Key.Value : Swift.Equatable {
  public static func == (a: _PreferenceWritingModifier<Key>, b: _PreferenceWritingModifier<Key>) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, *)
public struct PreferredColorSchemeKey : PreferenceKey {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public typealias Value = ColorScheme?
  public static func reduce(value: inout PreferredColorSchemeKey.Value, nextValue: () -> PreferredColorSchemeKey.Value) { _abiUnimplemented("PreferredColorSchemeKey: public static func reduce(value: inout PreferredColorSchemeKey.Value, nextValue: () -> PreferredColorSchemeKey.Value)") }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct PresentationDetent : Swift.Hashable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static let medium: PresentationDetent = PresentationDetent(_abiTag: 1)
  public static let large: PresentationDetent = PresentationDetent(_abiTag: 2)
  public static func fraction(_ fraction: CoreFoundation.CGFloat) -> PresentationDetent { _abiUnimplemented("PresentationDetent: public static func fraction(_ fraction: CoreFoundation.CGFloat) -> PresentationDetent") }
  public static func height(_ height: CoreFoundation.CGFloat) -> PresentationDetent { _abiUnimplemented("PresentationDetent: public static func height(_ height: CoreFoundation.CGFloat) -> PresentationDetent") }
  public static func custom<D>(_ type: D.Type) -> PresentationDetent where D : CustomPresentationDetent { _abiUnimplemented("PresentationDetent: public static func custom<D>(_ type: D.Type) -> PresentationDetent where D : CustomPresentationDetent") }
  @dynamicMemberLookup public struct Context {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public var maxDetentValue: CoreFoundation.CGFloat {
      get { _abiUnimplemented("PresentationDetent: public var maxDetentValue: CoreFoundation.CGFloat {") }
    }
    public subscript<T>(dynamicMember keyPath: Swift.KeyPath<EnvironmentValues, T>) -> T {
      get { _abiUnimplemented("PresentationDetent: public subscript<T>(dynamicMember keyPath: Swift.KeyPath<EnvironmentValues, T>) ") }
    }
  }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public static func == (a: PresentationDetent, b: PresentationDetent) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol PrimitiveButtonStyle {
  associatedtype Body : View
  @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
  typealias Configuration = PrimitiveButtonStyleConfiguration
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension PrimitiveButtonStyle where Self == BorderedProminentButtonStyle {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension PrimitiveButtonStyle where Self == PlainButtonStyle {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension PrimitiveButtonStyle where Self == DefaultButtonStyle {
}
@available(iOS 13.0, macOS 10.15, watchOS 8.0, *)
@available(tvOS, unavailable)
extension PrimitiveButtonStyle where Self == BorderlessButtonStyle {
}
@available(iOS 15.0, macOS 10.15, tvOS 13.0, watchOS 7.0, *)
extension PrimitiveButtonStyle where Self == BorderedButtonStyle {
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct PrimitiveButtonStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public struct Label : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public let role: ButtonRole?
  public let label: PrimitiveButtonStyleConfiguration.Label
  public func trigger() { _abiUnimplemented("PrimitiveButtonStyleConfiguration: public func trigger()") }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public protocol ProgressViewStyle {
  associatedtype Body : View
  @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
  typealias Configuration = ProgressViewStyleConfiguration
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension ProgressViewStyle where Self == DefaultProgressViewStyle {
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension ProgressViewStyle where Self == CircularProgressViewStyle {
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension ProgressViewStyle where Self == LinearProgressViewStyle {
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct ProgressViewStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public struct Label : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  public struct CurrentValueLabel : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  public let fractionCompleted: Swift.Double?
  public var label: ProgressViewStyleConfiguration.Label?
  public var currentValueLabel: ProgressViewStyleConfiguration.CurrentValueLabel?
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct ProjectionTransform {
  public var m11: CoreFoundation.CGFloat = 1.0, m12: CoreFoundation.CGFloat = 0.0, m13: CoreFoundation.CGFloat = 0.0
  public var m21: CoreFoundation.CGFloat = 0.0, m22: CoreFoundation.CGFloat = 1.0, m23: CoreFoundation.CGFloat = 0.0
  public var m31: CoreFoundation.CGFloat = 0.0, m32: CoreFoundation.CGFloat = 0.0, m33: CoreFoundation.CGFloat = 1.0
  @inlinable public init() {}
  @inlinable public init(_ m: CoreFoundation.CGAffineTransform) {
        m11 = m.a
        m12 = m.b
        m21 = m.c
        m22 = m.d
        m31 = m.tx
        m32 = m.ty
    }
  @inlinable public init(_ m: QuartzCore.CATransform3D) {
        m11 = m.m11
        m12 = m.m12
        m13 = m.m14
        m21 = m.m21
        m22 = m.m22
        m23 = m.m24
        m31 = m.m41
        m32 = m.m42
        m33 = m.m44
    }
  @inlinable public var isIdentity: Swift.Bool {
    get {
        return self == ProjectionTransform()
    }
  }
  @inlinable public var isAffine: Swift.Bool {
    get {
        return m13 == 0 && m23 == 0 && m33 == 1
    }
  }
  public mutating func invert() -> Swift.Bool { _abiUnimplemented("ProjectionTransform: public mutating func invert() -> Swift.Bool") }
  public func inverted() -> ProjectionTransform { _abiUnimplemented("ProjectionTransform: public func inverted() -> ProjectionTransform") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ProjectionTransform : Swift.Equatable {
  public static func == (a: ProjectionTransform, b: ProjectionTransform) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ProjectionTransform : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _ProposedSize {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _ProposedSize : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public static func == (a: _ProposedSize, b: _ProposedSize) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct RadialGradient : ShapeStyle, View {
  internal var gradient: Gradient
  internal var center: UnitPoint
  internal var startRadius: CoreFoundation.CGFloat
  internal var endRadius: CoreFoundation.CGFloat
  public init(gradient: Gradient, center: UnitPoint, startRadius: CoreFoundation.CGFloat, endRadius: CoreFoundation.CGFloat) { _abiUnimplemented("RadialGradient: public init(gradient: Gradient, center: UnitPoint, startRadius: CoreFoundation.CGFloat, endRadius: CoreFoundation.CGFloa") }
  public typealias Body = _ShapeView<Rectangle, RadialGradient>
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct RedactionReasons : Swift.OptionSet {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public let rawValue: Swift.Int
  public init(rawValue: Swift.Int) { self.rawValue = rawValue }
  public static let placeholder: RedactionReasons = RedactionReasons(rawValue: 1 << 0)
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public static let privacy: RedactionReasons = RedactionReasons(rawValue: 1 << 1)
  public typealias ArrayLiteralElement = RedactionReasons
  public typealias Element = RedactionReasons
  public typealias RawValue = Swift.Int
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct _RendererConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public enum Renderer {
    case `default`
    indirect case rasterized(_: _RendererConfiguration.RasterizationOptions = .init())
  }
  public var renderer: _RendererConfiguration.Renderer
  public var minFrameInterval: Swift.Double
  public init(renderer: _RendererConfiguration.Renderer = .default) { self.init(_abiTag: 0); _abiInertValue("_RendererConfiguration") }
  public static func rasterized(_ options: _RendererConfiguration.RasterizationOptions = .init()) -> _RendererConfiguration { _abiUnimplemented("_RendererConfiguration: public static func rasterized(_ options: _RendererConfiguration.RasterizationOptions = .init()) -> _RendererConfiguratio") }
  public struct RasterizationOptions {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
    public var colorMode: ColorRenderingMode
    public var rbColorMode: Swift.Int32?
    public var rendersAsynchronously: Swift.Bool
    public var isOpaque: Swift.Bool
    public var drawsPlatformViews: Swift.Bool
    public var prefersDisplayCompositing: Swift.Bool
    public var maxDrawableCount: Swift.Int
    public init() { self.init(_abiTag: 0); _abiInertValue("_RendererConfiguration") }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _Rotation3DEffect : GeometryEffect, Swift.Equatable {
  public var angle: Angle
  public var axis: (x: CoreFoundation.CGFloat, y: CoreFoundation.CGFloat, z: CoreFoundation.CGFloat)
  public var anchor: UnitPoint
  public var anchorZ: CoreFoundation.CGFloat
  public var perspective: CoreFoundation.CGFloat
  @inlinable public init(angle: Angle, axis: (x: CoreFoundation.CGFloat, y: CoreFoundation.CGFloat, z: CoreFoundation.CGFloat), anchor: UnitPoint = .center, anchorZ: CoreFoundation.CGFloat = 0, perspective: CoreFoundation.CGFloat = 1) {
        self.angle = angle
        self.axis = axis
        self.anchor = anchor
        self.anchorZ = anchorZ
        self.perspective = perspective
    }
  public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform { _abiUnimplemented("_Rotation3DEffect: public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform") }
  public typealias AnimatableData = AnimatablePair<Angle.AnimatableData, AnimatablePair<CoreFoundation.CGFloat, AnimatablePair<CoreFoundation.CGFloat, AnimatablePair<CoreFoundation.CGFloat, AnimatablePair<UnitPoint.AnimatableData, AnimatablePair<CoreFoundation.CGFloat, CoreFoundation.CGFloat>>>>>>
  public var animatableData: _Rotation3DEffect.AnimatableData {
    get { _abiUnimplemented("_Rotation3DEffect: public var animatableData: _Rotation3DEffect.AnimatableData {") }
    set {}
  }
  public static func == (lhs: _Rotation3DEffect, rhs: _Rotation3DEffect) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _Rotation3DEffect : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _RotationEffect : GeometryEffect, Swift.Equatable {
  public var angle: Angle
  public var anchor: UnitPoint
  @inlinable public init(angle: Angle, anchor: UnitPoint = .center) {
        self.angle = angle
        self.anchor = anchor
    }
  public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform { _abiUnimplemented("_RotationEffect: public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform") }
  public typealias AnimatableData = AnimatablePair<Angle.AnimatableData, UnitPoint.AnimatableData>
  public var animatableData: _RotationEffect.AnimatableData {
    get { _abiUnimplemented("_RotationEffect: public var animatableData: _RotationEffect.AnimatableData {") }
    set {}
  }
  public static func == (a: _RotationEffect, b: _RotationEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _RotationEffect : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _SafeAreaIgnoringLayout {
  public var edges: Edge.Set
  @inlinable public init(edges: Edge.Set = .all) {
        self.edges = edges
    }
  public typealias AnimatableData = EmptyAnimatableData
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _SafeAreaIgnoringLayout : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _SafeAreaIgnoringLayout : ViewModifier {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _SafeAreaIgnoringLayout : Swift.Sendable {}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@frozen public struct SafeAreaRegions : Swift.OptionSet {
  public let rawValue: Swift.UInt
  @inlinable public init(rawValue: Swift.UInt) { self.rawValue = rawValue }
  public static let container: SafeAreaRegions = SafeAreaRegions(rawValue: 1 << 0)
  public static let keyboard: SafeAreaRegions = SafeAreaRegions(rawValue: 1 << 1)
  public static let all: SafeAreaRegions = SafeAreaRegions(rawValue: 1 << 2)
  public typealias ArrayLiteralElement = SafeAreaRegions
  public typealias Element = SafeAreaRegions
  public typealias RawValue = Swift.UInt
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension SafeAreaRegions : Swift.Sendable {}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@frozen public struct _SafeAreaRegionsIgnoringLayout {
  public var regions: SafeAreaRegions
  public var edges: Edge.Set
  @inlinable internal init(regions: SafeAreaRegions, edges: Edge.Set) {
        self.regions = regions
        self.edges = edges
    }
  public typealias AnimatableData = EmptyAnimatableData
  public typealias Body = Swift.Never
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _SafeAreaRegionsIgnoringLayout : Animatable {}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _SafeAreaRegionsIgnoringLayout : ViewModifier {}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _SafeAreaRegionsIgnoringLayout : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _SaturationEffect : Swift.Equatable {
  public var amount: Swift.Double
  @inlinable public init(amount: Swift.Double) {
        self.amount = amount
    }
  public var animatableData: Swift.Double {
    get { _abiUnimplemented("_SaturationEffect: public var animatableData: Swift.Double {") }
    set {}
  }
  public static func == (a: _SaturationEffect, b: _SaturationEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias AnimatableData = Swift.Double
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _SaturationEffect : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _SaturationEffect : ViewModifier {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _SaturationEffect : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _ScaleEffect : GeometryEffect, Swift.Equatable {
  public var scale: CoreFoundation.CGSize
  public var anchor: UnitPoint
  @inlinable public init(scale: CoreFoundation.CGSize, anchor: UnitPoint = .center) {
        self.scale = scale
        self.anchor = anchor
    }
  public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform { _abiUnimplemented("_ScaleEffect: public func effectValue(size: CoreFoundation.CGSize) -> ProjectionTransform") }
  public typealias AnimatableData = AnimatablePair<CoreFoundation.CGSize.AnimatableData, UnitPoint.AnimatableData>
  public var animatableData: _ScaleEffect.AnimatableData {
    get { _abiUnimplemented("_ScaleEffect: public var animatableData: _ScaleEffect.AnimatableData {") }
    set {}
  }
  public static func == (a: _ScaleEffect, b: _ScaleEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _ScaleEffect : Swift.Sendable {}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public protocol _SceneModifier {
  associatedtype Body : Scene
  @SceneBuilder func body(content: Self.SceneContent) -> Self.Body
  typealias SceneContent = _SceneModifier_Content<Self>
  static func _makeScene(modifier: _GraphValue<Self>, inputs: _SceneInputs, body: @escaping (_Graph, _SceneInputs) -> _SceneOutputs) -> _SceneOutputs
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _SceneModifier where Self.Body == Swift.Never {
  public func body(content: Self.SceneContent) -> Self.Body { _abiUnimplemented("_SceneModifier: public func body(content: Self.SceneContent) -> Self.Body") }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _SceneModifier where Self : _GraphInputsModifier, Self.Body == Swift.Never {
  public static func _makeScene(modifier: _GraphValue<Self>, inputs: _SceneInputs, body: @escaping (_Graph, _SceneInputs) -> _SceneOutputs) -> _SceneOutputs { _abiUnimplemented("_SceneModifier: public static func _makeScene(modifier: _GraphValue<Self>, inputs: _SceneInputs, body: @escaping (_Graph, _SceneInputs) ") }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _SceneModifier {
  @inlinable internal func concat<T>(_ modifier: T) -> ModifiedContent<Self, T> {
        return .init(content: self, modifier: modifier)
    }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension _SceneModifier {
  public static func _makeScene(modifier: _GraphValue<Self>, inputs: _SceneInputs, body: @escaping (_Graph, _SceneInputs) -> _SceneOutputs) -> _SceneOutputs { _abiUnimplemented("_SceneModifier: public static func _makeScene(modifier: _GraphValue<Self>, inputs: _SceneInputs, body: @escaping (_Graph, _SceneInputs) ") }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct _SceneModifier_Content<Modifier> : Scene where Modifier : _SceneModifier {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static func _makeScene(scene: _GraphValue<_SceneModifier_Content<Modifier>>, inputs: _SceneInputs) -> _SceneOutputs { _abiUnimplemented("_SceneModifier_Content: public static func _makeScene(scene: _GraphValue<_SceneModifier_Content<Modifier>>, inputs: _SceneInputs) -> _SceneOutpu") }
  public typealias Body = Swift.Never
}

@available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
public struct ScrollBounceBehavior {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static var automatic: ScrollBounceBehavior {
    get { ScrollBounceBehavior(_abiTag: 1) }
  }
  public static var always: ScrollBounceBehavior {
    get { ScrollBounceBehavior(_abiTag: 2) }
  }
  public static var basedOnSize: ScrollBounceBehavior {
    get { ScrollBounceBehavior(_abiTag: 3) }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct ScrollIndicatorVisibility {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static var automatic: ScrollIndicatorVisibility {
    get { ScrollIndicatorVisibility(_abiTag: 1) }
  }
  public static var visible: ScrollIndicatorVisibility {
    get { ScrollIndicatorVisibility(_abiTag: 2) }
  }
  public static var hidden: ScrollIndicatorVisibility {
    get { ScrollIndicatorVisibility(_abiTag: 3) }
  }
  public static var never: ScrollIndicatorVisibility {
    get { ScrollIndicatorVisibility(_abiTag: 4) }
  }
}
@available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
extension ScrollIndicatorVisibility : Swift.Equatable {
  public static func == (a: ScrollIndicatorVisibility, b: ScrollIndicatorVisibility) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct ScrollViewProxy {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public func scrollTo<ID>(_ id: ID, anchor: UnitPoint? = nil) where ID : Swift.Hashable { _abiUnimplemented("ScrollViewProxy: public func scrollTo<ID>(_ id: ID, anchor: UnitPoint? = nil) where ID : Swift.Hashable") }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
@frozen public struct ScrollViewReader<Content> : View where Content : View {
  public var content: (ScrollViewProxy) -> Content
  @inlinable public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
        self.content = content
    }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("ScrollViewReader: @preconcurrency @MainActor public var body: some View {") }
  }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct SearchFieldPlacement {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static let automatic: SearchFieldPlacement = SearchFieldPlacement(_abiTag: 1)
  @available(tvOS, unavailable)
  public static let toolbar: SearchFieldPlacement = SearchFieldPlacement(_abiTag: 2)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public static let sidebar: SearchFieldPlacement = SearchFieldPlacement(_abiTag: 3)
  @available(iOS 15.0, watchOS 8.0, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  public static let navigationBarDrawer: SearchFieldPlacement = SearchFieldPlacement(_abiTag: 4)
  @available(iOS 15.0, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public static func navigationBarDrawer(displayMode: SearchFieldPlacement.NavigationBarDrawerDisplayMode) -> SearchFieldPlacement { _abiUnimplemented("SearchFieldPlacement: public static func navigationBarDrawer(displayMode: SearchFieldPlacement.NavigationBarDrawerDisplayMode) -> SearchFieldP") }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension SearchFieldPlacement {
  @available(iOS 15.0, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public struct NavigationBarDrawerDisplayMode {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public static let automatic: SearchFieldPlacement.NavigationBarDrawerDisplayMode = SearchFieldPlacement.NavigationBarDrawerDisplayMode(_abiTag: 1)
    public static let always: SearchFieldPlacement.NavigationBarDrawerDisplayMode = SearchFieldPlacement.NavigationBarDrawerDisplayMode(_abiTag: 2)
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Section<Parent, Content, Footer> {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section : View where Parent : View, Content : View, Footer : View {
  public typealias Body = Swift.Never
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public static func _viewListCount(inputs: _ViewListCountInputs) -> Swift.Int? { nil }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent : View, Content : View, Footer : View {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent == EmptyView, Content : View, Footer : View {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent : View, Content : View, Footer == EmptyView {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent == EmptyView, Content : View, Footer == EmptyView {
  public init(@ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("Section") }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Section where Parent == Text, Content : View, Footer == EmptyView {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("Section") }
  @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S : Swift.StringProtocol { _abiUnimplemented("Section: @_disfavoredOverload public init<S>(_ title: S, @ViewBuilder content: () -> Content) where S : Swift.StringProtocol") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent : View, Content : View, Footer : View {
  @available(iOS, deprecated: 100000.0, renamed: "Section(content:header:footer:)")
  @available(macOS, deprecated: 100000.0, renamed: "Section(content:header:footer:)")
  @available(tvOS, deprecated: 100000.0, renamed: "Section(content:header:footer:)")
  @available(watchOS, deprecated: 100000.0, renamed: "Section(content:header:footer:)")
  public init(header: Parent, footer: Footer, @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("Section") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent == EmptyView, Content : View, Footer : View {
  @available(iOS, deprecated: 100000.0, renamed: "Section(content:footer:)")
  @available(macOS, deprecated: 100000.0, renamed: "Section(content:footer:)")
  @available(tvOS, deprecated: 100000.0, renamed: "Section(content:footer:)")
  @available(watchOS, deprecated: 100000.0, renamed: "Section(content:footer:)")
  public init(footer: Footer, @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("Section") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Section where Parent : View, Content : View, Footer == EmptyView {
  @available(iOS, deprecated: 100000.0, renamed: "Section(content:header:)")
  @available(macOS, deprecated: 100000.0, renamed: "Section(content:header:)")
  @available(tvOS, deprecated: 100000.0, renamed: "Section(content:header:)")
  @available(watchOS, deprecated: 100000.0, renamed: "Section(content:header:)")
  public init(header: Parent, @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("Section") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
@available(watchOS, unavailable)
public struct SegmentedPickerStyle : PickerStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("SegmentedPickerStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<SegmentedPickerStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("SegmentedPickerStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<SegmentedPickerStyle, SelectionValue>>, inp") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<SegmentedPickerStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("SegmentedPickerStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<SegmentedPickerStyle, SelectionValue>>,") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct SequenceGesture<First, Second> : Gesture where First : Gesture, Second : Gesture {
  @frozen public enum Value {
    case first(First.Value)
    case second(First.Value, Second.Value?)
  }
  public var first: First
  public var second: Second
  @inlinable public init(_ first: First, _ second: Second) {
        (self.first, self.second) = (first, second)
    }
  public static func _makeGesture(gesture: _GraphValue<SequenceGesture<First, Second>>, inputs: _GestureInputs) -> _GestureOutputs<SequenceGesture<First, Second>.Value> { _abiUnimplemented("SequenceGesture: public static func _makeGesture(gesture: _GraphValue<SequenceGesture<First, Second>>, inputs: _GestureInputs) -> _Gestur") }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SequenceGesture.Value : Swift.Equatable where First.Value : Swift.Equatable, Second.Value : Swift.Equatable {
  public static func == (a: SequenceGesture<First, Second>.Value, b: SequenceGesture<First, Second>.Value) -> Swift.Bool { _abiUnimplemented("SequenceGesture: public static func == (a: SequenceGesture<First, Second>.Value, b: SequenceGesture<First, Second>.Value) -> Swift.Bool") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _ShadowEffect : EnvironmentalModifier, Swift.Equatable {
  public var color: Color
  public var radius: CoreFoundation.CGFloat
  public var offset: CoreFoundation.CGSize
  @inlinable public init(color: Color, radius: CoreFoundation.CGFloat, offset: CoreFoundation.CGSize) {
        self.color = color
        self.radius = radius
        self.offset = offset
    }
  public func resolve(in environment: EnvironmentValues) -> _ShadowEffect._Resolved { _abiUnimplemented("_ShadowEffect: public func resolve(in environment: EnvironmentValues) -> _ShadowEffect._Resolved") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public static var _requiresMainThread: Swift.Bool {
    get { _abiUnimplemented("_ShadowEffect: public static var _requiresMainThread: Swift.Bool {") }
  }
  @usableFromInline
  internal var _requiresMainThread: Swift.Bool {
    get { _abiUnimplemented("_ShadowEffect: internal var _requiresMainThread: Swift.Bool {") }
  }
  public struct _Resolved {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias AnimatableData = AnimatablePair<AnimatablePair<Swift.Float, AnimatablePair<Swift.Float, AnimatablePair<Swift.Float, Swift.Float>>>, AnimatablePair<CoreFoundation.CGFloat, CoreFoundation.CGSize.AnimatableData>>
    public var animatableData: _ShadowEffect._Resolved.AnimatableData {
      get { _abiUnimplemented("_ShadowEffect: public var animatableData: _ShadowEffect._Resolved.AnimatableData {") }
      set {}
    }
    public typealias Body = Swift.Never
  }
  public static func == (a: _ShadowEffect, b: _ShadowEffect) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias Body = Swift.Never
  public typealias ResolvedModifier = _ShadowEffect._Resolved
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _ShadowEffect._Resolved : Animatable {}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _ShadowEffect._Resolved : ViewModifier {}

@available(iOS 14.0, macOS 10.15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct SidebarListStyle : ListStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("SidebarListStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<SidebarListStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("SidebarListStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_ListValue<SidebarListStyle, SelectionValue>>, inputs: _") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<SidebarListStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("SidebarListStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_ListValue<SidebarListStyle, SelectionValue>>, input") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct SimultaneousGesture<First, Second> : Gesture where First : Gesture, Second : Gesture {
  @frozen public struct Value {
    public var first: First.Value?
    public var second: Second.Value?
  }
  public var first: First
  public var second: Second
  @inlinable public init(_ first: First, _ second: Second) {
        (self.first, self.second) = (first, second)
    }
  public static func _makeGesture(gesture: _GraphValue<SimultaneousGesture<First, Second>>, inputs: _GestureInputs) -> _GestureOutputs<SimultaneousGesture<First, Second>.Value> { _abiUnimplemented("SimultaneousGesture: public static func _makeGesture(gesture: _GraphValue<SimultaneousGesture<First, Second>>, inputs: _GestureInputs) -> _Ge") }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SimultaneousGesture.Value : Swift.Equatable where First.Value : Swift.Equatable, Second.Value : Swift.Equatable {
  public static func == (a: SimultaneousGesture<First, Second>.Value, b: SimultaneousGesture<First, Second>.Value) -> Swift.Bool { _abiUnimplemented("SimultaneousGesture: public static func == (a: SimultaneousGesture<First, Second>.Value, b: SimultaneousGesture<First, Second>.Value) -> Swif") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SimultaneousGesture.Value : Swift.Hashable where First.Value : Swift.Hashable, Second.Value : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@frozen public struct _SizeFittingRoot : _VariadicView.UnaryViewRoot {
  @usableFromInline
  internal var axes: Axis.Set
  @inlinable internal init(axes: Axis.Set) { self.axes = axes }
  public static func _makeView(root: _GraphValue<_SizeFittingRoot>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _ViewListOutputs) -> _ViewOutputs { _abiUnimplemented("_SizeFittingRoot: public static func _makeView(root: _GraphValue<_SizeFittingRoot>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _V") }
  public typealias Body = Swift.Never
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension _SizeFittingRoot : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@available(tvOS, unavailable)
public struct Slider<Label, ValueLabel> : View where Label : View, ValueLabel : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("Slider: @preconcurrency @MainActor public var body: some View {") }
  }
}
@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@available(tvOS, unavailable)
extension Slider {
}
@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@available(tvOS, unavailable)
extension Slider where ValueLabel == EmptyView {
}
@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@available(tvOS, unavailable)
extension Slider where Label == EmptyView, ValueLabel == EmptyView {
  @available(tvOS, unavailable)
  public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V> = 0...1, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void = { _ in }) where V : Swift.BinaryFloatingPoint, V.Stride : Swift.BinaryFloatingPoint { _abiUnimplemented("Slider: public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V> = 0...1, onEditingChanged: @escaping (Swift.Bool) -> S") }
  @available(tvOS, unavailable)
  public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void = { _ in }) where V : Swift.BinaryFloatingPoint, V.Stride : Swift.BinaryFloatingPoint { _abiUnimplemented("Slider: public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Swif") }
}
@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@available(tvOS, unavailable)
extension Slider {
  @available(tvOS, unavailable)
  @available(iOS, deprecated: 100000.0, renamed: "Slider(value:in:label:minimumValueLabel:maximumValueLabel:onEditingChanged:)")
  @available(macOS, deprecated: 100000.0, renamed: "Slider(value:in:label:minimumValueLabel:maximumValueLabel:onEditingChanged:)")
  @available(watchOS, deprecated: 100000.0, renamed: "Slider(value:in:label:minimumValueLabel:maximumValueLabel:onEditingChanged:)")
  public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V> = 0...1, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void = { _ in }, minimumValueLabel: ValueLabel, maximumValueLabel: ValueLabel, @ViewBuilder label: () -> Label) where V : Swift.BinaryFloatingPoint, V.Stride : Swift.BinaryFloatingPoint { _abiUnimplemented("Slider: public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V> = 0...1, onEditingChanged: @escaping (Swift.Bool) -> S") }
  @available(tvOS, unavailable)
  @available(iOS, deprecated: 100000.0, renamed: "Slider(value:in:step:label:minimumValueLabel:maximumValueLabel:onEditingChanged:)")
  @available(macOS, deprecated: 100000.0, renamed: "Slider(value:in:step:label:minimumValueLabel:maximumValueLabel:onEditingChanged:)")
  @available(watchOS, deprecated: 100000.0, renamed: "Slider(value:in:step:label:minimumValueLabel:maximumValueLabel:onEditingChanged:)")
  public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void = { _ in }, minimumValueLabel: ValueLabel, maximumValueLabel: ValueLabel, @ViewBuilder label: () -> Label) where V : Swift.BinaryFloatingPoint, V.Stride : Swift.BinaryFloatingPoint { _abiUnimplemented("Slider: public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Swif") }
}
@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@available(tvOS, unavailable)
extension Slider where ValueLabel == EmptyView {
  @available(tvOS, unavailable)
  @available(iOS, deprecated: 100000.0, renamed: "Slider(value:in:label:onEditingChanged:)")
  @available(macOS, deprecated: 100000.0, renamed: "Slider(value:in:label:onEditingChanged:)")
  @available(watchOS, deprecated: 100000.0, renamed: "Slider(value:in:label:onEditingChanged:)")
  @_disfavoredOverload public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V> = 0...1, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void = { _ in }, @ViewBuilder label: () -> Label) where V : Swift.BinaryFloatingPoint, V.Stride : Swift.BinaryFloatingPoint { _abiUnimplemented("Slider: @_disfavoredOverload public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V> = 0...1, onEditingChanged: @escap") }
  @available(tvOS, unavailable)
  @available(iOS, deprecated: 100000.0, renamed: "Slider(value:in:step:label:onEditingChanged:)")
  @available(macOS, deprecated: 100000.0, renamed: "Slider(value:in:step:label:onEditingChanged:)")
  @available(watchOS, deprecated: 100000.0, renamed: "Slider(value:in:step:label:onEditingChanged:)")
  @_disfavoredOverload public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void = { _ in }, @ViewBuilder label: () -> Label) where V : Swift.BinaryFloatingPoint, V.Stride : Swift.BinaryFloatingPoint { _abiUnimplemented("Slider: @_disfavoredOverload public init<V>(value: Binding<V>, in bounds: Swift.ClosedRange<V>, step: V.Stride = 1, onEditingCha") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _StrokedShape<S> : Shape where S : Shape {
  public var shape: S
  public var style: StrokeStyle
  @inlinable public init(shape: S, style: StrokeStyle) {
        self.shape = shape
        self.style = style
    }
  public func path(in rect: CoreFoundation.CGRect) -> Path { _abiUnimplemented("_StrokedShape: public func path(in rect: CoreFoundation.CGRect) -> Path") }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public static var role: ShapeRole {
    get { _abiUnimplemented("_StrokedShape: public static var role: ShapeRole {") }
  }
  public typealias AnimatableData = AnimatablePair<S.AnimatableData, StrokeStyle.AnimatableData>
  public var animatableData: _StrokedShape<S>.AnimatableData {
    get { _abiUnimplemented("_StrokedShape: public var animatableData: _StrokedShape<S>.AnimatableData {") }
    set {}
  }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public func sizeThatFits(_ proposal: ProposedViewSize) -> CoreFoundation.CGSize { _abiUnimplemented("_StrokedShape: public func sizeThatFits(_ proposal: ProposedViewSize) -> CoreFoundation.CGSize") }
  public typealias Body = _ShapeView<_StrokedShape<S>, ForegroundStyle>
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct StrokeStyle : Swift.Equatable {
  public var lineWidth: CoreFoundation.CGFloat
  public var lineCap: CoreGraphics.CGLineCap
  public var lineJoin: CoreGraphics.CGLineJoin
  public var miterLimit: CoreFoundation.CGFloat
  public var dash: [CoreFoundation.CGFloat]
  public var dashPhase: CoreFoundation.CGFloat
  public init(lineWidth: CoreFoundation.CGFloat = 1, lineCap: CoreGraphics.CGLineCap = .butt, lineJoin: CoreGraphics.CGLineJoin = .miter, miterLimit: CoreFoundation.CGFloat = 10, dash: [CoreFoundation.CGFloat] = [CGFloat](), dashPhase: CoreFoundation.CGFloat = 0) { _abiUnimplemented("StrokeStyle: public init(lineWidth: CoreFoundation.CGFloat = 1, lineCap: CoreGraphics.CGLineCap = .butt, lineJoin: CoreGraphics.CGLin") }
  public static func == (a: StrokeStyle, b: StrokeStyle) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension StrokeStyle : Animatable {
  public typealias AnimatableData = AnimatablePair<CoreFoundation.CGFloat, AnimatablePair<CoreFoundation.CGFloat, CoreFoundation.CGFloat>>
  public var animatableData: StrokeStyle.AnimatableData {
    get { _abiUnimplemented("StrokeStyle: public var animatableData: StrokeStyle.AnimatableData {") }
    set {}
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension StrokeStyle : Swift.Sendable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct SubmitLabel {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static var done: SubmitLabel {
    get { SubmitLabel(_abiTag: 1) }
  }
  public static var go: SubmitLabel {
    get { SubmitLabel(_abiTag: 2) }
  }
  public static var send: SubmitLabel {
    get { SubmitLabel(_abiTag: 3) }
  }
  public static var join: SubmitLabel {
    get { SubmitLabel(_abiTag: 4) }
  }
  public static var route: SubmitLabel {
    get { SubmitLabel(_abiTag: 5) }
  }
  public static var search: SubmitLabel {
    get { SubmitLabel(_abiTag: 6) }
  }
  public static var `return`: SubmitLabel {
    get { SubmitLabel(_abiTag: 7) }
  }
  public static var next: SubmitLabel {
    get { SubmitLabel(_abiTag: 8) }
  }
  public static var `continue`: SubmitLabel {
    get { SubmitLabel(_abiTag: 9) }
  }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct SubmitTriggers : Swift.OptionSet {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public typealias RawValue = Swift.Int
  public let rawValue: SubmitTriggers.RawValue
  public init(rawValue: SubmitTriggers.RawValue) { self.rawValue = rawValue }
  public static let text: SubmitTriggers = SubmitTriggers(rawValue: 1 << 0)
  public static let search: SubmitTriggers = SubmitTriggers(rawValue: 1 << 1)
  public typealias ArrayLiteralElement = SubmitTriggers
  public typealias Element = SubmitTriggers
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@available(tvOS, unavailable)
public struct SwitchToggleStyle : ToggleStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("SwitchToggleStyle") }
  @available(iOS, introduced: 14.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  @available(macOS, introduced: 11.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  @available(tvOS, unavailable)
  @available(watchOS, introduced: 7.0, deprecated: 100000.0, message: "Use ``View/tint(_)`` instead.")
  public init(tint: Color) { self.init(_abiTag: 0); _abiInertValue("SwitchToggleStyle") }
  public func makeBody(configuration: SwitchToggleStyle.Configuration) -> some View { _abiUnimplemented("SwitchToggleStyle: public func makeBody(configuration: SwitchToggleStyle.Configuration) -> some View") }
  
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct SymbolRenderingMode {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static let monochrome: SymbolRenderingMode = SymbolRenderingMode(_abiTag: 1)
  public static let multicolor: SymbolRenderingMode = SymbolRenderingMode(_abiTag: 2)
  public static let hierarchical: SymbolRenderingMode = SymbolRenderingMode(_abiTag: 3)
  public static let palette: SymbolRenderingMode = SymbolRenderingMode(_abiTag: 4)
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 7.0, *)
public struct TabView<SelectionValue, Content> : View where SelectionValue : Swift.Hashable, Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("TabView") }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("TabView: @preconcurrency @MainActor public var body: some View {") }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 7.0, *)
extension TabView where SelectionValue == Swift.Int {
  public init(@ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("TabView") }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public protocol TabViewStyle {
  static func _makeView<SelectionValue>(value: _GraphValue<_TabViewValue<Self, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable
  static func _makeViewList<SelectionValue>(value: _GraphValue<_TabViewValue<Self, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable
}
@available(iOS 14.0, tvOS 14.0, watchOS 7.0, *)
@available(macOS, unavailable)
extension TabViewStyle where Self == PageTabViewStyle {
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension TabViewStyle where Self == DefaultTabViewStyle {
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct _TabViewValue<Style, SelectionValue> where Style : TabViewStyle, SelectionValue : Swift.Hashable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal struct TagValueTraitKey<V> : _ViewTraitKey where V : Swift.Hashable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @usableFromInline
  @frozen internal enum Value {
    case untagged
    case tagged(V)
  }
  @inlinable internal static var defaultValue: TagValueTraitKey<V>.Value {
    get { .untagged }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public enum TextAlignment : Swift.Hashable, Swift.CaseIterable {
  case leading
  case center
  case trailing
  public static func == (a: TextAlignment, b: TextAlignment) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public typealias AllCases = [TextAlignment]
  public static var allCases: [TextAlignment] {
    get { _abiUnimplemented("TextAlignment: public static var allCases: [TextAlignment] {") }
  }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension TextAlignment : Swift.Sendable {}

@available(iOS 14.0, macOS 11.0, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct TextEditor : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(text: Binding<Swift.String>) { self.init(_abiTag: 0); _abiInertValue("TextEditor") }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("TextEditor: @preconcurrency @MainActor public var body: some View {") }
  }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct TextField<Label> : View where Label : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("TextField: @preconcurrency @MainActor public var body: some View {") }
  }
}
extension TextField where Label == Text {
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init(_ titleKey: LocalizedStringKey, text: Binding<Swift.String>, axis: Axis) { self.init(_abiTag: 0); _abiInertValue("TextField") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init(_ titleKey: LocalizedStringKey, text: Binding<Swift.String>, prompt: Text?, axis: Axis) { self.init(_abiTag: 0); _abiInertValue("TextField") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, axis: Axis) where S : Swift.StringProtocol { _abiUnimplemented("TextField: @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, axis: Axis) where S : Swift.StringProtocol") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, prompt: Text?, axis: Axis) where S : Swift.StringProtocol { _abiUnimplemented("TextField: @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, prompt: Text?, axis: Axis) where S : Swift.") }
}
extension TextField {
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init(text: Binding<Swift.String>, prompt: Text? = nil, axis: Axis, @ViewBuilder label: () -> Label) { self.init(_abiTag: 0); _abiInertValue("TextField") }
}
extension TextField where Label == Text {
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init(_ titleKey: LocalizedStringKey, text: Binding<Swift.String>, prompt: Text?) { self.init(_abiTag: 0); _abiInertValue("TextField") }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, prompt: Text?) where S : Swift.StringProtocol { _abiUnimplemented("TextField: @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, prompt: Text?) where S : Swift.StringProtoc") }
}
extension TextField {
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init(text: Binding<Swift.String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) { self.init(_abiTag: 0); _abiInertValue("TextField") }
}
extension TextField where Label == Text {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension TextField where Label == Text {
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Renamed TextField.init(_:text:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(macOS, introduced: 10.15, deprecated: 100000.0, message: "Renamed TextField.init(_:text:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "Renamed TextField.init(_:text:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(watchOS, introduced: 6.0, deprecated: 100000.0, message: "Renamed TextField.init(_:text:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  public init(_ titleKey: LocalizedStringKey, text: Binding<Swift.String>, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void, onCommit: @escaping () -> Swift.Void) { self.init(_abiTag: 0); _abiInertValue("TextField") }
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Renamed TextField.init(_:text:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(macOS, introduced: 10.15, deprecated: 100000.0, message: "Renamed TextField.init(_:text:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "Renamed TextField.init(_:text:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(watchOS, introduced: 6.0, deprecated: 100000.0, message: "Renamed TextField.init(_:text:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void, onCommit: @escaping () -> Swift.Void) where S : Swift.StringProtocol { _abiUnimplemented("TextField: @_disfavoredOverload public init<S>(_ title: S, text: Binding<Swift.String>, onEditingChanged: @escaping (Swift.Bool) ->") }
}
extension TextField where Label == Text {
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init<F>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil) where F : Foundation.ParseableFormatStyle, F.FormatOutput == Swift.String { _abiUnimplemented("TextField: public init<F>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil) where F :") }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  @_disfavoredOverload public init<S, F>(_ title: S, value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil) where S : Swift.StringProtocol, F : Foundation.ParseableFormatStyle, F.FormatOutput == Swift.String { _abiUnimplemented("TextField: @_disfavoredOverload public init<S, F>(_ title: S, value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil) where") }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init<F>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) where F : Foundation.ParseableFormatStyle, F.FormatOutput == Swift.String { _abiUnimplemented("TextField: public init<F>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) where F : ") }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  @_disfavoredOverload public init<S, F>(_ title: S, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) where S : Swift.StringProtocol, F : Foundation.ParseableFormatStyle, F.FormatOutput == Swift.String { _abiUnimplemented("TextField: @_disfavoredOverload public init<S, F>(_ title: S, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) where ") }
}
extension TextField {
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init<F>(value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil, @ViewBuilder label: () -> Label) where F : Foundation.ParseableFormatStyle, F.FormatOutput == Swift.String { _abiUnimplemented("TextField: public init<F>(value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil, @ViewBuilder label: () -> Label) where F ") }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init<F>(value: Binding<F.FormatInput>, format: F, prompt: Text? = nil, @ViewBuilder label: () -> Label) where F : Foundation.ParseableFormatStyle, F.FormatOutput == Swift.String { _abiUnimplemented("TextField: public init<F>(value: Binding<F.FormatInput>, format: F, prompt: Text? = nil, @ViewBuilder label: () -> Label) where F :") }
}
extension TextField where Label == Text {
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Foundation.Formatter, prompt: Text?) { _abiUnimplemented("TextField: public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Foundation.Formatter, prompt: Text?)") }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  @_disfavoredOverload public init<S, V>(_ title: S, value: Binding<V>, formatter: Foundation.Formatter, prompt: Text?) where S : Swift.StringProtocol { _abiUnimplemented("TextField: @_disfavoredOverload public init<S, V>(_ title: S, value: Binding<V>, formatter: Foundation.Formatter, prompt: Text?) wh") }
}
extension TextField {
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init<V>(value: Binding<V>, formatter: Foundation.Formatter, prompt: Text? = nil, @ViewBuilder label: () -> Label) { _abiUnimplemented("TextField: public init<V>(value: Binding<V>, formatter: Foundation.Formatter, prompt: Text? = nil, @ViewBuilder label: () -> Label)") }
}
extension TextField where Label == Text {
}
extension TextField where Label == Text {
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Renamed TextField.init(_:value:formatter:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(macOS, introduced: 10.15, deprecated: 100000.0, message: "Renamed TextField.init(_:value:formatter:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "Renamed TextField.init(_:value:formatter:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(watchOS, introduced: 6.0, deprecated: 100000.0, message: "Renamed TextField.init(_:value:formatter:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Foundation.Formatter, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void, onCommit: @escaping () -> Swift.Void) { _abiUnimplemented("TextField: public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Foundation.Formatter, onEditingChanged: @es") }
  @available(iOS, introduced: 13.0, deprecated: 100000.0, message: "Renamed TextField.init(_:value:formatter:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(macOS, introduced: 10.15, deprecated: 100000.0, message: "Renamed TextField.init(_:value:formatter:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(tvOS, introduced: 13.0, deprecated: 100000.0, message: "Renamed TextField.init(_:value:formatter:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @available(watchOS, introduced: 6.0, deprecated: 100000.0, message: "Renamed TextField.init(_:value:formatter:onEditingChanged:). Use View.onSubmit(of:_:) for functionality previously provided by the onCommit parameter. Use FocusState<T> and View.focused(_:equals:) for functionality previously provided by the onEditingChanged parameter.")
  @_disfavoredOverload public init<S, V>(_ title: S, value: Binding<V>, formatter: Foundation.Formatter, onEditingChanged: @escaping (Swift.Bool) -> Swift.Void, onCommit: @escaping () -> Swift.Void) where S : Swift.StringProtocol { _abiUnimplemented("TextField: @_disfavoredOverload public init<S, V>(_ title: S, value: Binding<V>, formatter: Foundation.Formatter, onEditingChanged:") }
}

@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
@available(macOS, unavailable)
public struct TextInputAutocapitalization {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static var never: TextInputAutocapitalization {
    get { TextInputAutocapitalization(_abiTag: 1) }
  }
  public static var words: TextInputAutocapitalization {
    get { TextInputAutocapitalization(_abiTag: 2) }
  }
  public static var sentences: TextInputAutocapitalization {
    get { TextInputAutocapitalization(_abiTag: 3) }
  }
  public static var characters: TextInputAutocapitalization {
    get { TextInputAutocapitalization(_abiTag: 4) }
  }
}
@available(iOS 15.0, tvOS 15.0, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
extension TextInputAutocapitalization {
  public init?(_ type: UIKit.UITextAutocapitalizationType) { return nil }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public protocol TimelineSchedule {
  typealias Mode = TimelineScheduleMode
  associatedtype Entries : Swift.Sequence where Self.Entries.Element == Foundation.Date
  func entries(from startDate: Foundation.Date, mode: Self.Mode) -> Self.Entries
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TimelineSchedule where Self == AnimationTimelineSchedule {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TimelineSchedule where Self == PeriodicTimelineSchedule {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TimelineSchedule where Self == EveryMinuteTimelineSchedule {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TimelineSchedule {
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public enum TimelineScheduleMode {
  case normal
  case lowFrequency
  public static func == (a: TimelineScheduleMode, b: TimelineScheduleMode) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TimelineScheduleMode : Swift.Equatable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TimelineScheduleMode : Swift.Hashable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct TimelineView<Schedule, Content> where Schedule : TimelineSchedule {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public struct Context {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
    public enum Cadence : Swift.Comparable {
      case live
      case seconds
      case minutes
      public static func == (a: TimelineView<Schedule, Content>.Context.Cadence, b: TimelineView<Schedule, Content>.Context.Cadence) -> Swift.Bool { _abiUnimplemented("TimelineView: public static func == (a: TimelineView<Schedule, Content>.Context.Cadence, b: TimelineView<Schedule, Content>.Context.Ca") }
      public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
      public static func < (a: TimelineView<Schedule, Content>.Context.Cadence, b: TimelineView<Schedule, Content>.Context.Cadence) -> Swift.Bool { _abiUnimplemented("TimelineView: public static func < (a: TimelineView<Schedule, Content>.Context.Cadence, b: TimelineView<Schedule, Content>.Context.Cad") }
      public var hashValue: Swift.Int {
        get { var h = Hasher(); hash(into: &h); return h.finalize() }
      }
    }
    public let date: Foundation.Date
    public let cadence: TimelineView<Schedule, Content>.Context.Cadence
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TimelineView : View where Content : View {
  public typealias Body = Swift.Never
  @available(iOS, deprecated, introduced: 15.0, message: "Use TimelineViewDefaultContext for the type of the context parameter passed into TimelineView's content closure to resolve this warning. The new version of this initializer, using TimelineViewDefaultContext, improves compilation performance by using an independent generic type signature, which helps avoid unintended cyclical type dependencies.")
  @available(macOS, deprecated, introduced: 12.0, message: "Use TimelineViewDefaultContext for the type of the context parameter passed into TimelineView's content closure to resolve this warning. The new version of this initializer, using TimelineViewDefaultContext, improves compilation performance by using an independent generic type signature, which helps avoid unintended cyclical type dependencies.")
  @available(watchOS, deprecated, introduced: 8.0, message: "Use TimelineViewDefaultContext for the type of the context parameter passed into TimelineView's content closure to resolve this warning. The new version of this initializer, using TimelineViewDefaultContext, improves compilation performance by using an independent generic type signature, which helps avoid unintended cyclical type dependencies.")
  @available(tvOS, deprecated, introduced: 15.0, message: "Use TimelineViewDefaultContext for the type of the context parameter passed into TimelineView's content closure to resolve this warning. The new version of this initializer, using TimelineViewDefaultContext, improves compilation performance by using an independent generic type signature, which helps avoid unintended cyclical type dependencies.")
  @_disfavoredOverload public init(_ schedule: Schedule, @ViewBuilder content: @escaping (TimelineView<Schedule, Content>.Context) -> Content) { self.init(_abiTag: 0); _abiInertValue("TimelineView") }
  public static func _makeView(view: _GraphValue<TimelineView<Schedule, Content>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
}
extension TimelineView where Content : View {
  @available(iOS 16.4, macOS 13.3, watchOS 9.4, tvOS 16.4, *)
  @usableFromInline
  @_disfavoredOverload internal init(_ schedule: Schedule, @ViewBuilder content: @escaping (TimelineView<PeriodicTimelineSchedule, Swift.Never>.Context) -> Content) { _abiUnimplemented("TimelineView: @_disfavoredOverload internal init(_ schedule: Schedule, @ViewBuilder content: @escaping (TimelineView<PeriodicTimelineS") }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension TimelineView.Context.Cadence : Swift.Hashable {}

// !! TimelineViewDefaultContext: not in the iOS 16.5 interface

@available(iOS 14.5, macOS 11.3, tvOS 14.5, watchOS 7.4, *)
public struct TitleAndIconLabelStyle : LabelStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("TitleAndIconLabelStyle") }
  public func makeBody(configuration: TitleAndIconLabelStyle.Configuration) -> some View { _abiUnimplemented("TitleAndIconLabelStyle: public func makeBody(configuration: TitleAndIconLabelStyle.Configuration) -> some View") }
  
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct TitleOnlyLabelStyle : LabelStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("TitleOnlyLabelStyle") }
  public func makeBody(configuration: TitleOnlyLabelStyle.Configuration) -> some View { _abiUnimplemented("TitleOnlyLabelStyle: public func makeBody(configuration: TitleOnlyLabelStyle.Configuration) -> some View") }
  
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Toggle<Label> : View where Label : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(isOn: Binding<Swift.Bool>, @ViewBuilder label: () -> Label) { self.init(_abiTag: 0); _abiInertValue("Toggle") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init<C>(sources: C, isOn: Swift.KeyPath<C.Element, Binding<Swift.Bool>>, @ViewBuilder label: () -> Label) where C : Swift.RandomAccessCollection { _abiUnimplemented("Toggle: public init<C>(sources: C, isOn: Swift.KeyPath<C.Element, Binding<Swift.Bool>>, @ViewBuilder label: () -> Label) where C") }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("Toggle: @preconcurrency @MainActor public var body: some View {") }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Toggle where Label == ToggleStyleConfiguration.Label {
  @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
  public init(_ configuration: ToggleStyleConfiguration) { self.init(_abiTag: 0); _abiInertValue("Toggle") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension Toggle where Label == Text {
  public init(_ titleKey: LocalizedStringKey, isOn: Binding<Swift.Bool>) { self.init(_abiTag: 0); _abiInertValue("Toggle") }
  @_disfavoredOverload public init<S>(_ title: S, isOn: Binding<Swift.Bool>) where S : Swift.StringProtocol { _abiUnimplemented("Toggle: @_disfavoredOverload public init<S>(_ title: S, isOn: Binding<Swift.Bool>) where S : Swift.StringProtocol") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public init<C>(_ titleKey: LocalizedStringKey, sources: C, isOn: Swift.KeyPath<C.Element, Binding<Swift.Bool>>) where C : Swift.RandomAccessCollection { _abiUnimplemented("Toggle: public init<C>(_ titleKey: LocalizedStringKey, sources: C, isOn: Swift.KeyPath<C.Element, Binding<Swift.Bool>>) where C ") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  @_disfavoredOverload public init<S, C>(_ title: S, sources: C, isOn: Swift.KeyPath<C.Element, Binding<Swift.Bool>>) where S : Swift.StringProtocol, C : Swift.RandomAccessCollection { _abiUnimplemented("Toggle: @_disfavoredOverload public init<S, C>(_ title: S, sources: C, isOn: Swift.KeyPath<C.Element, Binding<Swift.Bool>>) wher") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol ToggleStyle {
  associatedtype Body : View
  @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
  typealias Configuration = ToggleStyleConfiguration
}
@available(iOS 13.0, macOS 10.15, watchOS 6.0, *)
@available(tvOS, unavailable)
extension ToggleStyle where Self == SwitchToggleStyle {
}
@available(iOS 15.0, macOS 12.0, watchOS 9.0, *)
@available(tvOS, unavailable)
extension ToggleStyle where Self == ButtonToggleStyle {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ToggleStyle where Self == DefaultToggleStyle {
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ToggleStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public struct Label : View {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Body = Swift.Never
  }
  public let label: ToggleStyleConfiguration.Label
  @Binding public var isOn: Swift.Bool
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public var isMixed: Swift.Bool
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct ToolbarItemGroup<Content> : ToolbarContent where Content : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("ToolbarItemGroup") }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public static func _makeToolbar(content: _GraphValue<ToolbarItemGroup<Content>>, inputs: _ToolbarInputs) -> _ToolbarOutputs { _abiUnimplemented("ToolbarItemGroup: public static func _makeToolbar(content: _GraphValue<ToolbarItemGroup<Content>>, inputs: _ToolbarInputs) -> _ToolbarOutp") }
  public static func _makeContent(content: _GraphValue<ToolbarItemGroup<Content>>, inputs: _GraphInputs, resolved: inout _ToolbarItemList) { _abiUnimplemented("ToolbarItemGroup: public static func _makeContent(content: _GraphValue<ToolbarItemGroup<Content>>, inputs: _GraphInputs, resolved: inout _") }
  public typealias Body = Swift.Never
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension ToolbarItemGroup {
  public init<C, L>(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> C, @ViewBuilder label: () -> L) where Content == LabeledToolbarItemGroupContent<C, L>, C : View, L : View { _abiUnimplemented("ToolbarItemGroup: public init<C, L>(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> C, @ViewBuilder label: () ->") }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct ToolbarPlacement {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static var automatic: ToolbarPlacement {
    get { ToolbarPlacement(_abiTag: 1) }
  }
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public static var bottomBar: ToolbarPlacement {
    get { ToolbarPlacement(_abiTag: 2) }
  }
  @available(macOS, unavailable)
  public static var navigationBar: ToolbarPlacement {
    get { ToolbarPlacement(_abiTag: 3) }
  }
  @available(iOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public static var windowToolbar: ToolbarPlacement {
    get { ToolbarPlacement(_abiTag: 4) }
  }
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  public static var tabBar: ToolbarPlacement {
    get { ToolbarPlacement(_abiTag: 5) }
  }
  @available(iOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public init<ID>(id: ID) where ID : Swift.Hashable { _abiUnimplemented("ToolbarPlacement: public init<ID>(id: ID) where ID : Swift.Hashable") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _TraitWritingModifier<Trait> where Trait : _ViewTraitKey {
  public let value: Trait.Value
  @inlinable public init(value: Trait.Value) {
        self.value = value
    }
  public static func _makeView(modifier: _GraphValue<_TraitWritingModifier<Trait>>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs { _darlingPassthrough(Self.self, inputs, body) }
  public static func _makeViewList(modifier: _GraphValue<_TraitWritingModifier<Trait>>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs { body(_Graph(), inputs) }
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public static func _viewListCount(inputs: _ViewListCountInputs, body: (_ViewListCountInputs) -> Swift.Int?) -> Swift.Int? { nil }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _TraitWritingModifier : ViewModifier {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _TransactionModifier : ViewModifier, _GraphInputsModifier {
  public var transform: (inout Transaction) -> Swift.Void
  @inlinable public init(transform: @escaping (inout Transaction) -> Swift.Void) {
        self.transform = transform
    }
  public static func _makeInputs(modifier: _GraphValue<_TransactionModifier>, inputs: inout _GraphInputs) { _abiUnimplemented("_TransactionModifier: public static func _makeInputs(modifier: _GraphValue<_TransactionModifier>, inputs: inout _GraphInputs)") }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal struct TransitionTraitKey : _ViewTraitKey {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @inlinable internal static var defaultValue: AnyTransition {
    get { .opacity }
  }
  @usableFromInline
  internal typealias Value = AnyTransition
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct _TrimmedShape<S> : Shape where S : Shape {
  public var shape: S
  public var startFraction: CoreFoundation.CGFloat
  public var endFraction: CoreFoundation.CGFloat
  @inlinable public init(shape: S, startFraction: CoreFoundation.CGFloat = 0, endFraction: CoreFoundation.CGFloat = 1) {
        self.shape = shape
        self.startFraction = startFraction
        self.endFraction = endFraction
    }
  public func path(in rect: CoreFoundation.CGRect) -> Path { _abiUnimplemented("_TrimmedShape: public func path(in rect: CoreFoundation.CGRect) -> Path") }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public static var role: ShapeRole {
    get { _abiUnimplemented("_TrimmedShape: public static var role: ShapeRole {") }
  }
  public typealias AnimatableData = AnimatablePair<S.AnimatableData, AnimatablePair<CoreFoundation.CGFloat, CoreFoundation.CGFloat>>
  public var animatableData: _TrimmedShape<S>.AnimatableData {
    get { _abiUnimplemented("_TrimmedShape: public var animatableData: _TrimmedShape<S>.AnimatableData {") }
    set {}
  }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public func sizeThatFits(_ proposal: ProposedViewSize) -> CoreFoundation.CGSize { _abiUnimplemented("_TrimmedShape: public func sizeThatFits(_ proposal: ProposedViewSize) -> CoreFoundation.CGSize") }
  public typealias Body = _ShapeView<_TrimmedShape<S>, ForegroundStyle>
}

@available(iOS 16.0, tvOS 16.0, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
public struct UIHostingConfiguration<Content, Background> : UIKit.UIContentConfiguration where Content : View, Background : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public func background<B>(@ViewBuilder content: () -> B) -> UIHostingConfiguration<Content, B> where B : View { _abiUnimplemented("UIHostingConfiguration: public func background<B>(@ViewBuilder content: () -> B) -> UIHostingConfiguration<Content, B> where B : View") }
  public func background<S>(_ style: S) -> UIHostingConfiguration<Content, _UIHostingConfigurationBackgroundView<S>> where S : ShapeStyle { _abiUnimplemented("UIHostingConfiguration: public func background<S>(_ style: S) -> UIHostingConfiguration<Content, _UIHostingConfigurationBackgroundView<S>> where") }
  public func margins(_ edges: Edge.Set = .all, _ length: CoreFoundation.CGFloat) -> UIHostingConfiguration<Content, Background> { _abiUnimplemented("UIHostingConfiguration: public func margins(_ edges: Edge.Set = .all, _ length: CoreFoundation.CGFloat) -> UIHostingConfiguration<Content, Backg") }
  public func margins(_ edges: Edge.Set = .all, _ insets: EdgeInsets) -> UIHostingConfiguration<Content, Background> { _abiUnimplemented("UIHostingConfiguration: public func margins(_ edges: Edge.Set = .all, _ insets: EdgeInsets) -> UIHostingConfiguration<Content, Background>") }
  public func minSize(width: CoreFoundation.CGFloat? = nil, height: CoreFoundation.CGFloat? = nil) -> UIHostingConfiguration<Content, Background> { _abiUnimplemented("UIHostingConfiguration: public func minSize(width: CoreFoundation.CGFloat? = nil, height: CoreFoundation.CGFloat? = nil) -> UIHostingConfigurati") }
  @_Concurrency.MainActor public func makeContentView() -> any UIKit.UIView & UIKit.UIContentView { _abiUnimplemented("UIHostingConfiguration: @_Concurrency.MainActor public func makeContentView() -> any UIKit.UIView & UIKit.UIContentView") }
  public func updated(for state: any UIKit.UIConfigurationState) -> UIHostingConfiguration<Content, Background> { _abiUnimplemented("UIHostingConfiguration: public func updated(for state: any UIKit.UIConfigurationState) -> UIHostingConfiguration<Content, Background>") }
}
@available(iOS 16.0, tvOS 16.0, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
extension UIHostingConfiguration where Background == EmptyView {
  public init(@ViewBuilder content: () -> Content) { self.init(_abiTag: 0); _abiInertValue("UIHostingConfiguration") }
}

@available(iOS 16.0, tvOS 16.0, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
public struct _UIHostingConfigurationBackgroundView<Style> : View where Style : ShapeStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @preconcurrency @MainActor public var body: some View {
    get { _abiUnimplemented("_UIHostingConfigurationBackgroundView: @preconcurrency @MainActor public var body: some View {") }
  }
}

@available(iOS 16.0, tvOS 16.0, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
public struct UIHostingControllerSizingOptions : Swift.OptionSet {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  public let rawValue: Swift.Int
  public init(rawValue: Swift.Int) { self.rawValue = rawValue }
  public static let preferredContentSize: UIHostingControllerSizingOptions = UIHostingControllerSizingOptions(rawValue: 1 << 0)
  public static let intrinsicContentSize: UIHostingControllerSizingOptions = UIHostingControllerSizingOptions(rawValue: 1 << 1)
  public typealias ArrayLiteralElement = UIHostingControllerSizingOptions
  public typealias Element = UIHostingControllerSizingOptions
  public typealias RawValue = Swift.Int
}

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
@available(macOS, unavailable)
public protocol _UIHostingViewable : AnyObject {
  var rootView: AnyView { get set }
  func _render(seconds: Swift.Double)
  func _forEachIdentifiedView(body: (_IdentifiedViewProxy) -> Swift.Void)
  func sizeThatFits(in size: CoreFoundation.CGSize) -> CoreFoundation.CGSize
  var _disableSafeArea: Swift.Bool { get set }
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  var _rendererConfiguration: _RendererConfiguration { get set }
  var _rendererObject: Swift.AnyObject? { get }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@frozen public struct UnitPoint : Swift.Hashable {
  public var x: CoreFoundation.CGFloat
  public var y: CoreFoundation.CGFloat
  @inlinable public init() {
        self.init(x: 0, y: 0)
    }
  @inlinable public init(x: CoreFoundation.CGFloat, y: CoreFoundation.CGFloat) {
        self.x = x
        self.y = y
    }
  public static let zero: UnitPoint = UnitPoint(x: 0, y: 0)
  public static let center: UnitPoint = UnitPoint(x: 0.5, y: 0.5)
  public static let leading: UnitPoint = UnitPoint(x: 0, y: 0.5)
  public static let trailing: UnitPoint = UnitPoint(x: 1, y: 0.5)
  public static let top: UnitPoint = UnitPoint(x: 0.5, y: 0)
  public static let bottom: UnitPoint = UnitPoint(x: 0.5, y: 1)
  public static let topLeading: UnitPoint = UnitPoint(x: 0, y: 0)
  public static let topTrailing: UnitPoint = UnitPoint(x: 1, y: 0)
  public static let bottomLeading: UnitPoint = UnitPoint(x: 0, y: 1)
  public static let bottomTrailing: UnitPoint = UnitPoint(x: 1, y: 1)
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public static func == (a: UnitPoint, b: UnitPoint) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension UnitPoint : Animatable {
  public typealias AnimatableData = AnimatablePair<CoreFoundation.CGFloat, CoreFoundation.CGFloat>
  public var animatableData: UnitPoint.AnimatableData {
    get { _abiUnimplemented("UnitPoint: public var animatableData: UnitPoint.AnimatableData {") }
    set {}
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension UnitPoint : Swift.Sendable {}

@available(iOS 13.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public enum UserInterfaceSizeClass {
  case compact
  case regular
  public static func == (a: UserInterfaceSizeClass, b: UserInterfaceSizeClass) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
extension UserInterfaceSizeClass {
  @available(iOS 14.0, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public init?(_ uiUserInterfaceSizeClass: UIKit.UIUserInterfaceSizeClass) { return nil }
}
@available(iOS 13.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension UserInterfaceSizeClass : Swift.Equatable {}
@available(iOS 13.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension UserInterfaceSizeClass : Swift.Hashable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct _VariadicView_Children {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _VariadicView_Children : View {
  public static func _makeViewList(view: _GraphValue<_VariadicView.Children>, inputs: _ViewListInputs) -> _ViewListOutputs { _ViewListOutputs(view: _darlingUnsupportedView(Self.self, inputs.viewInputs)) }
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public static func _viewListCount(inputs: _ViewListCountInputs) -> Swift.Int? { nil }
  public typealias Body = Swift.Never
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _VariadicView_Children : Swift.RandomAccessCollection {
  public struct Element : View, Swift.Identifiable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public var id: Swift.AnyHashable {
      get { _abiUnimplemented("_VariadicView_Children: public var id: Swift.AnyHashable {") }
    }
    public func id<ID>(as _: ID.Type = ID.self) -> ID? where ID : Swift.Hashable { _abiUnimplemented("_VariadicView_Children: public func id<ID>(as _: ID.Type = ID.self) -> ID? where ID : Swift.Hashable") }
    public subscript<Trait>(key: Trait.Type) -> Trait.Value where Trait : _ViewTraitKey {
      get { _abiUnimplemented("_VariadicView_Children: public subscript<Trait>(key: Trait.Type) -> Trait.Value where Trait : _ViewTrait") }
      set {}
    }
    public static func _makeView(view: _GraphValue<_VariadicView_Children.Element>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
    public typealias Body = Swift.Never
    public typealias ID = Swift.AnyHashable
  }
  public var startIndex: Swift.Int {
    get { _abiUnimplemented("_VariadicView_Children: public var startIndex: Swift.Int {") }
  }
  public var endIndex: Swift.Int {
    get { _abiUnimplemented("_VariadicView_Children: public var endIndex: Swift.Int {") }
  }
  public subscript(index: Swift.Int) -> _VariadicView_Children.Element {
    get { _abiUnimplemented("_VariadicView_Children: public subscript(index: Swift.Int) -> _VariadicView_Children.Element {") }
  }
  public typealias Index = Swift.Int
  public typealias Indices = Swift.Range<Swift.Int>
  public typealias Iterator = Swift.IndexingIterator<_VariadicView_Children>
  public typealias SubSequence = Swift.Slice<_VariadicView_Children>
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol _VariadicView_MultiViewRoot : _VariadicView_ViewRoot {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _VariadicView_MultiViewRoot {
  public static func _makeView(root: _GraphValue<Self>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _ViewListOutputs) -> _ViewOutputs { _abiUnimplemented("_VariadicView_MultiViewRoot: public static func _makeView(root: _GraphValue<Self>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _ViewListOutpu") }
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public static func _viewListCount(inputs: _ViewListCountInputs, body: (_ViewListCountInputs) -> Swift.Int?) -> Swift.Int? { nil }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol _VariadicView_UnaryViewRoot : _VariadicView_ViewRoot {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _VariadicView_UnaryViewRoot {
  public static func _makeViewList(root: _GraphValue<Self>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs { _abiUnimplemented("_VariadicView_UnaryViewRoot: public static func _makeViewList(root: _GraphValue<Self>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInp") }
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public static func _viewListCount(inputs: _ViewListCountInputs, body: (_ViewListCountInputs) -> Swift.Int?) -> Swift.Int? { nil }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol _VariadicView_ViewRoot : _VariadicView_Root {
  static func _makeView(root: _GraphValue<Self>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _ViewListOutputs) -> _ViewOutputs
  static func _makeViewList(root: _GraphValue<Self>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  static func _viewListCount(inputs: _ViewListCountInputs, body: (_ViewListCountInputs) -> Swift.Int?) -> Swift.Int?
  associatedtype Body : View
  @ViewBuilder func body(children: _VariadicView.Children) -> Self.Body
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _VariadicView_ViewRoot where Self.Body == Swift.Never {
  public func body(children: _VariadicView.Children) -> Swift.Never { _abiUnimplemented("_VariadicView_ViewRoot: public func body(children: _VariadicView.Children) -> Swift.Never") }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _VariadicView_ViewRoot {
  public static func _makeView(root: _GraphValue<Self>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _ViewListOutputs) -> _ViewOutputs { _abiUnimplemented("_VariadicView_ViewRoot: public static func _makeView(root: _GraphValue<Self>, inputs: _ViewInputs, body: (_Graph, _ViewInputs) -> _ViewListOutpu") }
  public static func _makeViewList(root: _GraphValue<Self>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInputs) -> _ViewListOutputs) -> _ViewListOutputs { _abiUnimplemented("_VariadicView_ViewRoot: public static func _makeViewList(root: _GraphValue<Self>, inputs: _ViewListInputs, body: @escaping (_Graph, _ViewListInp") }
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public static func _viewListCount(inputs: _ViewListCountInputs) -> Swift.Int? { nil }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol _VectorMath : Animatable {
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension _VectorMath {
  @inlinable public var magnitude: Swift.Double {
    get {
        return animatableData.magnitudeSquared.squareRoot()
    }
  }
  @inlinable public mutating func negate() {
        animatableData = .zero - animatableData
    }
  @inlinable prefix public static func - (operand: Self) -> Self {
        var result = operand
        result.negate()
        return result
    }
  @inlinable public static func += (lhs: inout Self, rhs: Self) {
        lhs.animatableData += rhs.animatableData
    }
  @inlinable public static func + (lhs: Self, rhs: Self) -> Self {
        var result = lhs
        result += rhs
        return result
    }
  @inlinable public static func -= (lhs: inout Self, rhs: Self) {
        lhs.animatableData -= rhs.animatableData
    }
  @inlinable public static func - (lhs: Self, rhs: Self) -> Self {
        var result = lhs
        result -= rhs
        return result
    }
  @inlinable public static func *= (lhs: inout Self, rhs: Swift.Double) {
        lhs.animatableData.scale(by: rhs)
    }
  @inlinable public static func * (lhs: Self, rhs: Swift.Double) -> Self {
        var result = lhs
        result *= rhs
        return result
    }
  @inlinable public static func /= (lhs: inout Self, rhs: Swift.Double) {
        lhs *= 1 / rhs
    }
  @inlinable public static func / (lhs: Self, rhs: Swift.Double) -> Self {
        var result = lhs
        result /= rhs
        return result
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public enum VerticalEdge : Swift.Int8, Swift.CaseIterable, Swift.Codable {
  case top
  case bottom
  @frozen public struct Set : Swift.OptionSet {
    public typealias Element = VerticalEdge.Set
    public let rawValue: Swift.Int8
    public init(rawValue: Swift.Int8) { self.rawValue = rawValue }
    public static let top: VerticalEdge.Set = VerticalEdge.Set(rawValue: 1 << 0)
    public static let bottom: VerticalEdge.Set = VerticalEdge.Set(rawValue: 1 << 1)
    public static let all: VerticalEdge.Set = VerticalEdge.Set(rawValue: 1 << 2)
    public init(_ e: VerticalEdge) { _abiUnimplemented("VerticalEdge: public init(_ e: VerticalEdge)") }
    public typealias ArrayLiteralElement = VerticalEdge.Set.Element
    public typealias RawValue = Swift.Int8
  }
  public init?(rawValue: Swift.Int8) { return nil }
  public typealias AllCases = [VerticalEdge]
  public typealias RawValue = Swift.Int8
  public static var allCases: [VerticalEdge] {
    get { _abiUnimplemented("VerticalEdge: public static var allCases: [VerticalEdge] {") }
  }
  public var rawValue: Swift.Int8 {
    get { _abiUnimplemented("VerticalEdge: public var rawValue: Swift.Int8 {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerticalEdge : Swift.Equatable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerticalEdge : Swift.Hashable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerticalEdge : Swift.RawRepresentable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerticalEdge : Swift.Sendable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerticalEdge.Set : Swift.Sendable {}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct ViewDimensions {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public var width: CoreFoundation.CGFloat {
    get { _abiUnimplemented("ViewDimensions: public var width: CoreFoundation.CGFloat {") }
  }
  public var height: CoreFoundation.CGFloat {
    get { _abiUnimplemented("ViewDimensions: public var height: CoreFoundation.CGFloat {") }
  }
  public subscript(guide: HorizontalAlignment) -> CoreFoundation.CGFloat {
    get { _abiUnimplemented("ViewDimensions: public subscript(guide: HorizontalAlignment) -> CoreFoundation.CGFloat {") }
  }
  public subscript(guide: VerticalAlignment) -> CoreFoundation.CGFloat {
    get { _abiUnimplemented("ViewDimensions: public subscript(guide: VerticalAlignment) -> CoreFoundation.CGFloat {") }
  }
  public subscript(explicit guide: HorizontalAlignment) -> CoreFoundation.CGFloat? {
    get { _abiUnimplemented("ViewDimensions: public subscript(explicit guide: HorizontalAlignment) -> CoreFoundation.CGFloat?") }
  }
  public subscript(explicit guide: VerticalAlignment) -> CoreFoundation.CGFloat? {
    get { _abiUnimplemented("ViewDimensions: public subscript(explicit guide: VerticalAlignment) -> CoreFoundation.CGFloat? {") }
  }
}
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension ViewDimensions : Swift.Equatable {
  public static func == (lhs: ViewDimensions, rhs: ViewDimensions) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct ViewSpacing {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public static let zero: ViewSpacing = ViewSpacing(_abiTag: 1)
  public init() { self.init(_abiTag: 0); _abiInertValue("ViewSpacing") }
  public mutating func formUnion(_ other: ViewSpacing, edges: Edge.Set = .all) { _abiUnimplemented("ViewSpacing: public mutating func formUnion(_ other: ViewSpacing, edges: Edge.Set = .all)") }
  public func union(_ other: ViewSpacing, edges: Edge.Set = .all) -> ViewSpacing { _abiUnimplemented("ViewSpacing: public func union(_ other: ViewSpacing, edges: Edge.Set = .all) -> ViewSpacing") }
  public func distance(to next: ViewSpacing, along axis: Axis) -> CoreFoundation.CGFloat { _abiUnimplemented("ViewSpacing: public func distance(to next: ViewSpacing, along axis: Axis) -> CoreFoundation.CGFloat") }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@frozen public struct ViewThatFits<Content> : View where Content : View {
  @usableFromInline
  internal var _tree: _VariadicView.Tree<_SizeFittingRoot, Content>
  @inlinable public init(in axes: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: () -> Content) {
        _tree = .init(root: _SizeFittingRoot(axes: axes), content: content())
    }
  public static func _makeView(view: _GraphValue<ViewThatFits<Content>>, inputs: _ViewInputs) -> _ViewOutputs { _darlingUnsupportedView(Self.self, inputs) }
  public typealias Body = Swift.Never
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public protocol _ViewTraitKey {
  associatedtype Value
  static var defaultValue: Self.Value { get }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public enum Visibility : Swift.Hashable, Swift.CaseIterable {
  case automatic
  case visible
  case hidden
  public static func == (a: Visibility, b: Visibility) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public typealias AllCases = [Visibility]
  public static var allCases: [Visibility] {
    get { _abiUnimplemented("Visibility: public static var allCases: [Visibility] {") }
  }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Visibility : Swift.Sendable {}

@available(iOS 13.0, watchOS 6.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
public struct WheelPickerStyle : PickerStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0); _abiInertValue("WheelPickerStyle") }
  public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<WheelPickerStyle, SelectionValue>>, inputs: _ViewInputs) -> _ViewOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("WheelPickerStyle: public static func _makeView<SelectionValue>(value: _GraphValue<_PickerValue<WheelPickerStyle, SelectionValue>>, inputs:") }
  public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<WheelPickerStyle, SelectionValue>>, inputs: _ViewListInputs) -> _ViewListOutputs where SelectionValue : Swift.Hashable { _abiUnimplemented("WheelPickerStyle: public static func _makeViewList<SelectionValue>(value: _GraphValue<_PickerValue<WheelPickerStyle, SelectionValue>>, inp") }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
@usableFromInline
internal struct ZIndexTraitKey : _ViewTraitKey {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @inlinable internal static var defaultValue: Swift.Double {
    get { 0.0 }
  }
  @usableFromInline
  internal typealias Value = Swift.Double
}

