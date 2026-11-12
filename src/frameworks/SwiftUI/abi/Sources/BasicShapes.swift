import CoreFoundation

@frozen public struct AnimatablePair<First: VectorArithmetic, Second: VectorArithmetic>: VectorArithmetic {
    public var first: First
    public var second: Second
    @inlinable public init(_ first: First, _ second: Second) { self.first = first; self.second = second }
    @inlinable public static var zero: Self { .init(.zero, .zero) }
    @inlinable public static func + (lhs: Self, rhs: Self) -> Self { .init(lhs.first + rhs.first, lhs.second + rhs.second) }
    @inlinable public static func - (lhs: Self, rhs: Self) -> Self { .init(lhs.first - rhs.first, lhs.second - rhs.second) }
    @inlinable public static func += (lhs: inout Self, rhs: Self) { lhs.first += rhs.first; lhs.second += rhs.second }
    @inlinable public static func -= (lhs: inout Self, rhs: Self) { lhs.first -= rhs.first; lhs.second -= rhs.second }
    @inlinable public mutating func scale(by rhs: Double) { first.scale(by: rhs); second.scale(by: rhs) }
    @inlinable public var magnitudeSquared: Double { first.magnitudeSquared + second.magnitudeSquared }
}
extension CGSize: Animatable {
    public typealias AnimatableData = AnimatablePair<CGFloat, CGFloat>
    @inlinable public var animatableData: AnimatableData {
        get { .init(width, height) }
        set { width = newValue.first; height = newValue.second }
    }
}
extension CGPoint: Animatable {
    public typealias AnimatableData = AnimatablePair<CGFloat, CGFloat>
    @inlinable public var animatableData: AnimatableData {
        get { .init(x, y) }
        set { x = newValue.first; y = newValue.second }
    }
}
public enum RoundedCornerStyle: Hashable { case circular, continuous }
public protocol InsettableShape: Shape {
    associatedtype InsetShape: InsettableShape
    func inset(by amount: CGFloat) -> InsetShape
}
extension Shape {
    public var body: _ShapeView<Self, ForegroundStyle> { .init(shape: self, style: .init()) }
    @inlinable public func fill<S: ShapeStyle>(_ content: S, style: FillStyle = .init()) -> some View {
        _ShapeView(shape: self, style: content, fillStyle: style)
    }
    @inlinable public func fill(style: FillStyle = .init()) -> some View { _ShapeView(shape: self, style: ForegroundStyle(), fillStyle: style) }
}
@frozen public struct Rectangle: Shape {
    @inlinable public init() {}
    public typealias AnimatableData = EmptyAnimatableData
    public func path(in rect: CGRect) -> Path { Path(rect) }
}
@frozen public struct RoundedRectangle: Shape {
    public var cornerSize: CGSize
    public var style: RoundedCornerStyle
    @inlinable public init(cornerSize: CGSize, style: RoundedCornerStyle = .circular) { self.cornerSize = cornerSize; self.style = style }
    @inlinable public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .circular) { self.init(cornerSize: .init(width: cornerRadius, height: cornerRadius), style: style) }
    public var animatableData: CGSize.AnimatableData { get { cornerSize.animatableData } set { cornerSize.animatableData = newValue } }
    public func path(in rect: CGRect) -> Path { Path(roundedRect: rect, cornerSize: cornerSize, style: style) }
}
@frozen public struct Capsule: Shape {
    public var style: RoundedCornerStyle
    @inlinable public init(style: RoundedCornerStyle = .circular) { self.style = style }
    public typealias AnimatableData = EmptyAnimatableData
    public func path(in rect: CGRect) -> Path { Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) / 2, style: style) }
}
@frozen public struct Ellipse: Shape {
    @inlinable public init() {}
    public typealias AnimatableData = EmptyAnimatableData
    public func path(in rect: CGRect) -> Path { Path(ellipseIn: rect) }
}
@frozen public struct Circle: Shape {
    @inlinable public init() {}
    public typealias AnimatableData = EmptyAnimatableData
    public func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        return Path(ellipseIn: CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side))
    }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        let size = proposal.replacingUnspecifiedDimensions()
        let side = min(size.width, size.height)
        return .init(width: side, height: side)
    }
}
extension Rectangle: InsettableShape {
    @inlinable public func inset(by amount: CGFloat) -> some InsettableShape { _Inset(amount: amount) }
    @usableFromInline @frozen struct _Inset: InsettableShape {
        @usableFromInline var amount: CGFloat
        @usableFromInline init(amount: CGFloat) { self.amount = amount }
        @usableFromInline var animatableData: CGFloat { get { amount } set { amount = newValue } }
        @usableFromInline func path(in rect: CGRect) -> Path { rect.width <= amount * 2 || rect.height <= amount * 2 ? Path() : Path(rect.insetBy(dx: amount, dy: amount)) }
        @inlinable func inset(by amount: CGFloat) -> Self { .init(amount: self.amount + amount) }
    }
}
extension RoundedRectangle: InsettableShape {
    @inlinable public func inset(by amount: CGFloat) -> some InsettableShape { _Inset(base: self, amount: amount) }
    @usableFromInline @frozen struct _Inset: InsettableShape {
        @usableFromInline var base: RoundedRectangle
        @usableFromInline var amount: CGFloat
        @usableFromInline init(base: RoundedRectangle, amount: CGFloat) { self.base = base; self.amount = amount }
        @usableFromInline var animatableData: AnimatablePair<RoundedRectangle.AnimatableData, CGFloat> {
            get { .init(base.animatableData, amount) }
            set { base.animatableData = newValue.first; amount = newValue.second }
        }
        @usableFromInline func path(in rect: CGRect) -> Path {
            guard rect.width > amount * 2 && rect.height > amount * 2 else { return Path() }
            return Path(roundedRect: rect.insetBy(dx: amount, dy: amount), cornerSize: CGSize(width: max(0, base.cornerSize.width - amount), height: max(0, base.cornerSize.height - amount)), style: base.style)
        }
        @inlinable func inset(by amount: CGFloat) -> Self { .init(base: base, amount: self.amount + amount) }
    }
}
extension Capsule: InsettableShape {
    @inlinable public func inset(by amount: CGFloat) -> some InsettableShape { _Inset(amount: amount) }
    @usableFromInline @frozen struct _Inset: InsettableShape {
        @usableFromInline var amount: CGFloat
        @usableFromInline init(amount: CGFloat) { self.amount = amount }
        @usableFromInline var animatableData: CGFloat { get { amount } set { amount = newValue } }
        @usableFromInline func path(in rect: CGRect) -> Path { rect.width <= amount * 2 || rect.height <= amount * 2 ? Path() : Capsule().path(in: rect.insetBy(dx: amount, dy: amount)) }
        @inlinable func inset(by amount: CGFloat) -> Self { .init(amount: self.amount + amount) }
    }
}
extension Ellipse: InsettableShape {
    @inlinable public func inset(by amount: CGFloat) -> some InsettableShape { _Inset(amount: amount) }
    @usableFromInline @frozen struct _Inset: InsettableShape {
        @usableFromInline var amount: CGFloat
        @usableFromInline init(amount: CGFloat) { self.amount = amount }
        @usableFromInline var animatableData: CGFloat { get { amount } set { amount = newValue } }
        @usableFromInline func path(in rect: CGRect) -> Path { rect.width <= amount * 2 || rect.height <= amount * 2 ? Path() : Path(ellipseIn: rect.insetBy(dx: amount, dy: amount)) }
        @inlinable func inset(by amount: CGFloat) -> Self { .init(amount: self.amount + amount) }
    }
}
extension Circle: InsettableShape {
    @inlinable public func inset(by amount: CGFloat) -> some InsettableShape { _Inset(amount: amount) }
    @usableFromInline @frozen struct _Inset: InsettableShape {
        @usableFromInline var amount: CGFloat
        @usableFromInline init(amount: CGFloat) { self.amount = amount }
        @usableFromInline var animatableData: CGFloat { get { amount } set { amount = newValue } }
        @usableFromInline func path(in rect: CGRect) -> Path { rect.width <= amount * 2 || rect.height <= amount * 2 ? Path() : Circle().path(in: rect.insetBy(dx: amount, dy: amount)) }
        @inlinable func inset(by amount: CGFloat) -> Self { .init(amount: self.amount + amount) }
    }
}
extension Path: Shape {
    public typealias AnimatableData = EmptyAnimatableData
    public func path(in rect: CGRect) -> Path { self }
}

/// The radii of a rectangle's four corners. The stored corners are physical (left and right); the
/// leading and trailing spellings are the SDK's, emitted into apps.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@frozen public struct RectangleCornerRadii: Equatable, Animatable {
    @usableFromInline var topLeft: CGFloat
    @usableFromInline var topRight: CGFloat
    @usableFromInline var bottomRight: CGFloat
    @usableFromInline var bottomLeft: CGFloat
    @_alwaysEmitIntoClient public var topLeading: CGFloat { get { topLeft } set { topLeft = newValue } }
    @_alwaysEmitIntoClient public var bottomLeading: CGFloat { get { bottomLeft } set { bottomLeft = newValue } }
    @_alwaysEmitIntoClient public var bottomTrailing: CGFloat { get { bottomRight } set { bottomRight = newValue } }
    @_alwaysEmitIntoClient public var topTrailing: CGFloat { get { topRight } set { topRight = newValue } }
    @usableFromInline init(topLeft: CGFloat, topRight: CGFloat, bottomRight: CGFloat, bottomLeft: CGFloat) {
        self.topLeft = topLeft; self.topRight = topRight; self.bottomRight = bottomRight; self.bottomLeft = bottomLeft
    }
    @_alwaysEmitIntoClient public init(topLeading: CGFloat = 0, bottomLeading: CGFloat = 0, bottomTrailing: CGFloat = 0, topTrailing: CGFloat = 0) {
        self.init(topLeft: topLeading, topRight: topTrailing, bottomRight: bottomTrailing, bottomLeft: bottomLeading)
    }
    public typealias AnimatableData = AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>
    public var animatableData: AnimatableData {
        get { AnimatablePair(AnimatablePair(topLeft, topRight), AnimatablePair(bottomRight, bottomLeft)) }
        set { (topLeft, topRight, bottomRight, bottomLeft) = (newValue.first.first, newValue.first.second, newValue.second.first, newValue.second.second) }
    }
}

/// A rectangle whose corners each have their own radius.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@frozen public struct UnevenRoundedRectangle: Shape {
    public var cornerRadii: RectangleCornerRadii
    public var style: RoundedCornerStyle
    @inlinable public init(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) {
        self.cornerRadii = cornerRadii
        self.style = style
    }
    @_alwaysEmitIntoClient public init(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0,
                                       topTrailingRadius: CGFloat = 0, style: RoundedCornerStyle = .continuous) {
        self.init(cornerRadii: .init(topLeading: topLeadingRadius, bottomLeading: bottomLeadingRadius,
                                     bottomTrailing: bottomTrailingRadius, topTrailing: topTrailingRadius), style: style)
    }
    /// Each corner is a quadratic curve through the rectangle's corner, its radius clamped to half
    /// the shorter side.
    public func path(in rect: CGRect) -> Path {
        let limit = min(rect.width, rect.height) / 2
        func clamp(_ radius: CGFloat) -> CGFloat { max(0, min(radius, limit)) }
        let tl = clamp(cornerRadii.topLeft), tr = clamp(cornerRadii.topRight)
        let br = clamp(cornerRadii.bottomRight), bl = clamp(cornerRadii.bottomLeft)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
    public typealias AnimatableData = RectangleCornerRadii.AnimatableData
    public var animatableData: AnimatableData {
        get { cornerRadii.animatableData }
        set { cornerRadii.animatableData = newValue }
    }
}
