// Public protocol slots and frozen value storage follow the pinned iOS SDK.
// Rendering animated values and general paths is separate from these contracts.
import CoreFoundation

public protocol VectorArithmetic: AdditiveArithmetic {
    mutating func scale(by rhs: Double)
    var magnitudeSquared: Double { get }
}
public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic
    var animatableData: AnimatableData { get set }
    static func _makeAnimatable(value: inout _GraphValue<Self>, inputs: _GraphInputs)
}
@frozen public struct EmptyAnimatableData: VectorArithmetic {
    @inlinable public init() {}
    @inlinable public static var zero: Self { Self() }
    @inlinable public static func += (lhs: inout Self, rhs: Self) {}
    @inlinable public static func -= (lhs: inout Self, rhs: Self) {}
    @inlinable public static func + (lhs: Self, rhs: Self) -> Self { Self() }
    @inlinable public static func - (lhs: Self, rhs: Self) -> Self { Self() }
    @inlinable public mutating func scale(by rhs: Double) {}
    @inlinable public var magnitudeSquared: Double { 0 }
}
extension Animatable where AnimatableData == EmptyAnimatableData {
    @inlinable public var animatableData: EmptyAnimatableData { get { .init() } set {} }
    public static func _makeAnimatable(value: inout _GraphValue<Self>, inputs: _GraphInputs) {}
}
extension Animatable {
    public static func _makeAnimatable(value: inout _GraphValue<Self>, inputs: _GraphInputs) {
        fatalError("SwiftUI: animated graph values are unsupported")
    }
}
extension Animatable where Self: VectorArithmetic {
    public var animatableData: Self { get { self } set { self = newValue } }
}
extension Double: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= rhs }
    public var magnitudeSquared: Double { self * self }
}
extension Float: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= Float(rhs) }
    public var magnitudeSquared: Double { Double(self * self) }
}
extension CGFloat: VectorArithmetic {
    public mutating func scale(by rhs: Double) { self *= CGFloat(rhs) }
    public var magnitudeSquared: Double { Double(self * self) }
}

@frozen public struct ProposedViewSize: Equatable {
    public var width, height: CGFloat?
    @inlinable public init(width: CGFloat?, height: CGFloat?) { self.width = width; self.height = height }
    @inlinable public init(_ size: CGSize) { self.init(width: size.width, height: size.height) }
    @inlinable public func replacingUnspecifiedDimensions(by size: CGSize = CGSize(width: 10, height: 10)) -> CGSize {
        CGSize(width: width ?? size.width, height: height ?? size.height)
    }
    public static let zero = Self(width: 0, height: 0)
    public static let unspecified = Self(width: nil, height: nil)
    public static let infinity = Self(width: .infinity, height: .infinity)
}
public enum ShapeRole: Hashable { case fill, stroke, separator }
public protocol Shape: Animatable, View {
    func path(in rect: CGRect) -> Path
    static var role: ShapeRole { get }
    func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize
}
extension Shape {
    public static var role: ShapeRole { .fill }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { proposal.replacingUnspecifiedDimensions() }
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let shape = _ShapeView(shape: view.value, style: ForegroundStyle())
        return _ShapeView<Self, ForegroundStyle>._makeView(view: _GraphValue(value: shape), inputs: inputs)
    }
    public static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        _ViewListOutputs(view: _makeView(view: view, inputs: inputs.viewInputs))
    }
}

// Indirect payloads are resilient in the SDK. Clients only own their references.
@usableFromInline struct FixedRoundedRect: Equatable { let rect: CGRect; let corner: CGSize; let style: RoundedCornerStyle }
@usableFromInline struct StrokedPath: Equatable { let path: Path }
@usableFromInline struct TrimmedPath: Equatable { let path: Path; let from, to: CGFloat }
@frozen public struct Path: Equatable {
    @usableFromInline final class PathBox: Equatable {
        var elements: [Element]
        init(_ elements: [Element]) { self.elements = elements }
        @usableFromInline static func == (lhs: PathBox, rhs: PathBox) -> Bool { lhs.elements == rhs.elements }
    }
    @usableFromInline @frozen enum Storage: Equatable {
        case empty
        case rect(CGRect)
        case ellipse(CGRect)
        indirect case roundedRect(FixedRoundedRect)
        indirect case stroked(StrokedPath)
        indirect case trimmed(TrimmedPath)
        case path(PathBox)
    }
    @usableFromInline var storage: Storage
    public init() { storage = .empty }
    public init(_ rect: CGRect) { storage = .rect(rect) }
    public init(ellipseIn rect: CGRect) { storage = .ellipse(rect) }

}
@frozen public struct FillStyle: Equatable {
    public var isEOFilled, isAntialiased: Bool
    @inlinable public init(eoFill: Bool = false, antialiased: Bool = true) { isEOFilled = eoFill; isAntialiased = antialiased }
}
@frozen public struct _ShapeView<Content: Shape, Style: ShapeStyle>: View {
    public var shape: Content
    public var style: Style
    public var fillStyle: FillStyle
    @inlinable public init(shape: Content, style: Style, fillStyle: FillStyle = FillStyle()) {
        self.shape = shape; self.style = style; self.fillStyle = fillStyle
    }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        makeShapeOutput(view.value.shape, style: view.value.style, fill: view.value.fillStyle, inputs: inputs)
    }
}
// Empty animation data is a real unit vector; there is nothing to interpolate.
extension _AspectRatioLayout: Animatable { public typealias AnimatableData = EmptyAnimatableData }
extension _FrameLayout: Animatable { public typealias AnimatableData = EmptyAnimatableData }
