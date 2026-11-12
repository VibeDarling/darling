// Animation, with the SDK's frozen layout (one reference to a box). Darling's SwiftUI applies every
// change at once, so an animation only records what was asked for: its curve and timing.
import CoreFoundation

@usableFromInline internal class AnimationBoxBase {
    let kind: String
    let duration: Double
    init(kind: String, duration: Double) { self.kind = kind; self.duration = duration }
}

@frozen public struct Animation: Equatable {
    internal var box: AnimationBoxBase
    init(_ kind: String, duration: Double = 0.35) { box = AnimationBoxBase(kind: kind, duration: duration) }
    public static func == (lhs: Animation, rhs: Animation) -> Bool { lhs.box === rhs.box }

    public static let `default` = Animation("default")
    public static func spring(response: Double = 0.55, dampingFraction: Double = 0.825, blendDuration: Double = 0) -> Animation { Animation("spring", duration: response) }
    public static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: Double = 0.25) -> Animation { Animation("interactiveSpring", duration: response) }
    public static func interpolatingSpring(mass: Double = 1.0, stiffness: Double, damping: Double, initialVelocity: Double = 0.0) -> Animation { Animation("interpolatingSpring") }
    public static func easeInOut(duration: Double) -> Animation { Animation("easeInOut", duration: duration) }
    public static var easeInOut: Animation { Animation("easeInOut") }
    public static func easeIn(duration: Double) -> Animation { Animation("easeIn", duration: duration) }
    public static var easeIn: Animation { Animation("easeIn") }
    public static func easeOut(duration: Double) -> Animation { Animation("easeOut", duration: duration) }
    public static var easeOut: Animation { Animation("easeOut") }
    public static func linear(duration: Double) -> Animation { Animation("linear", duration: duration) }
    public static var linear: Animation { Animation("linear") }
    public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: Double = 0.35) -> Animation { Animation("timingCurve", duration: duration) }
    public func delay(_ delay: Double) -> Animation { self }
    public func speed(_ speed: Double) -> Animation { self }
    public func repeatCount(_ repeatCount: Int, autoreverses: Bool = true) -> Animation { self }
    public func repeatForever(autoreverses: Bool = true) -> Animation { self }
}

extension Animation: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "Animation(\(box.kind), \(box.duration)s)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: ["kind": box.kind, "duration": box.duration]) }
}

/// Runs `body` at once: there are no animations to start.
public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    try body()
}

/// Runs `body` at once with the transaction unused.
public func withTransaction<Result>(_ transaction: Transaction, _ body: () throws -> Result) rethrows -> Result {
    try body()
}
