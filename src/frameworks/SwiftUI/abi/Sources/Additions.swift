// Smaller pieces of the iOS 16.5 SDK's SwiftUI that apps import: concatenated and image text,
// paths from Core Graphics, UIColor from Color, Binding as a collection, format specifiers in
// localized strings, and list reordering.
import Foundation
import CoreFoundation
import CoreGraphics
import UIKit

// MARK: - Text

/// Two texts as one; each part's own modifiers are not kept.
private final class ConcatenatedTextStorage: AnyTextStorage {
    let first: Text, second: Text
    init(_ first: Text, _ second: Text) { self.first = first; self.second = second }
    private static func resolve(_ text: Text) -> (String, [[String: Any]]) {
        switch text.storage {
        case .verbatim(let value): return (value, [])
        case .anyTextStorage(let storage): return storage.resolve()
        }
    }
    override func resolve() -> (String, [[String: Any]]) {
        let (a, aRuns) = Self.resolve(first), (b, bRuns) = Self.resolve(second)
        let offset = a.utf16.count
        let shifted = bRuns.map { run -> [String: Any] in
            var run = run
            if let start = run["start"] as? Int { run["start"] = start + offset }
            if let end = run["end"] as? Int { run["end"] = end + offset }
            return run
        }
        return (a + b, aRuns + shifted)
    }
    override func isEqual(to other: AnyTextStorage) -> Bool {
        guard let other = other as? ConcatenatedTextStorage else { return false }
        return first == other.first && second == other.second
    }
}

extension Text {
    public static func + (lhs: Text, rhs: Text) -> Text {
        var result = Text(verbatim: "")
        result.storage = .anyTextStorage(ConcatenatedTextStorage(lhs, rhs))
        return result
    }
    /// Images inside text are not drawn here.
    public init(_ image: Image) { self.init(verbatim: "") }
}

// MARK: - Path

extension Path {
    public init(_ path: CGPath) {
        self.init()
        var elements: [Element] = []
        withUnsafeMutablePointer(to: &elements) { list in
            path.apply(info: list) { info, element in
                let list = info!.assumingMemoryBound(to: [Path.Element].self)
                let points = element.pointee.points
                switch element.pointee.type {
                case .moveToPoint: list.pointee.append(.move(to: points[0]))
                case .addLineToPoint: list.pointee.append(.line(to: points[0]))
                case .addQuadCurveToPoint: list.pointee.append(.quadCurve(to: points[1], control: points[0]))
                case .addCurveToPoint: list.pointee.append(.curve(to: points[2], control1: points[0], control2: points[1]))
                case .closeSubpath: list.pointee.append(.closeSubpath)
                @unknown default: break
                }
            }
        }
        if !elements.isEmpty { storage = .path(PathBox(elements)) }
    }

    /// As CGPathAddArc: in quarter-turn Bézier segments, joined to the current point by a line.
    public mutating func addArc(center: CGPoint, radius: CGFloat, startAngle: Angle, endAngle: Angle, clockwise: Bool, transform: CGAffineTransform = .identity) {
        var start = startAngle.radians, end = endAngle.radians
        if clockwise { while end > start { end -= 2 * .pi } } else { while end < start { end += 2 * .pi } }
        func point(_ angle: Double) -> CGPoint {
            CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
        }
        var arc = Path()
        arc.move(to: point(start))
        let segments = max(1, Int((abs(end - start) / (.pi / 2)).rounded(.up)))
        let step = (end - start) / Double(segments)
        let k = CGFloat(4.0 / 3.0 * tan(step / 4)) * radius
        for i in 0 ..< segments {
            let a = start + step * Double(i), b = a + step
            let p0 = point(a), p1 = point(b)
            arc.addCurve(to: p1,
                         control1: CGPoint(x: p0.x - k * CGFloat(sin(a)), y: p0.y + k * CGFloat(cos(a))),
                         control2: CGPoint(x: p1.x + k * CGFloat(sin(b)), y: p1.y - k * CGFloat(cos(b))))
        }
        var arcElements = arc.applying(transform).elements
        if currentPoint != nil, case .move(let first)? = arcElements.first { arcElements[0] = .line(to: first) }
        var result = elements
        result += arcElements
        storage = .path(PathBox(result))
    }
}

// MARK: - UIColor

extension UIColor {
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    @available(macOS, unavailable)
    convenience public init(_ color: Color) {
        let paint = color.provider.resolve()
        self.init(red: CGFloat(paint.red), green: CGFloat(paint.green), blue: CGFloat(paint.blue), alpha: CGFloat(paint.opacity))
    }
}

// MARK: - Binding

extension Binding {
    /// A binding to the value of `base`, or nil while it is nil.
    public init?(_ base: Binding<Value?>) {
        guard let initial = base.wrappedValue else { return nil }
        self.init(get: { base.wrappedValue ?? initial }, set: { base.wrappedValue = $0 })
    }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Binding : Swift.Identifiable where Value : Swift.Identifiable {
    public var id: Value.ID { wrappedValue.id }
    public typealias ID = Value.ID
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Binding : Swift.Sequence where Value : Swift.MutableCollection {
    public typealias Element = Binding<Value.Element>
    public typealias Iterator = Swift.IndexingIterator<Binding<Value>>
    public typealias SubSequence = Swift.Slice<Binding<Value>>
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Binding : Swift.Collection where Value : Swift.MutableCollection {
    public typealias Index = Value.Index
    public typealias Indices = Value.Indices
    public var startIndex: Binding<Value>.Index { wrappedValue.startIndex }
    public var endIndex: Binding<Value>.Index { wrappedValue.endIndex }
    public var indices: Value.Indices { wrappedValue.indices }
    public func index(after i: Binding<Value>.Index) -> Binding<Value>.Index { wrappedValue.index(after: i) }
    public func formIndex(after i: inout Binding<Value>.Index) { wrappedValue.formIndex(after: &i) }
    public subscript(position: Binding<Value>.Index) -> Binding<Value>.Element {
        Binding<Value.Element>(get: { self.wrappedValue[position] }, set: { self.wrappedValue[position] = $0 })
    }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Binding : Swift.BidirectionalCollection where Value : Swift.BidirectionalCollection, Value : Swift.MutableCollection {
    public func index(before i: Binding<Value>.Index) -> Binding<Value>.Index { wrappedValue.index(before: i) }
    public func formIndex(before i: inout Binding<Value>.Index) { wrappedValue.formIndex(before: &i) }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Binding : Swift.RandomAccessCollection where Value : Swift.MutableCollection, Value : Swift.RandomAccessCollection {
}

// MARK: - Lists

extension MutableCollection {
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var items = Array(self)
        let moving = source.map { items[$0] }
        for offset in source.reversed() { items.remove(at: offset) }
        items.insert(contentsOf: moving, at: destination - source.filter { $0 < destination }.count)
        for (index, item) in zip(indices, items) { self[index] = item }
    }
}

// MARK: - Format specifiers

public protocol _FormatSpecifiable : Swift.Equatable {
    associatedtype _Arg : Swift.CVarArg
    var _arg: Self._Arg { get }
    var _specifier: Swift.String { get }
}
extension Int : _FormatSpecifiable { public var _arg: Int64 { Int64(self) }; public var _specifier: String { "%lld" } }
extension Int8 : _FormatSpecifiable { public var _arg: Int32 { Int32(self) }; public var _specifier: String { "%d" } }
extension Int16 : _FormatSpecifiable { public var _arg: Int32 { Int32(self) }; public var _specifier: String { "%d" } }
extension Int32 : _FormatSpecifiable { public var _arg: Int32 { self }; public var _specifier: String { "%d" } }
extension Int64 : _FormatSpecifiable { public var _arg: Int64 { self }; public var _specifier: String { "%lld" } }
extension UInt : _FormatSpecifiable { public var _arg: UInt64 { UInt64(self) }; public var _specifier: String { "%llu" } }
extension UInt8 : _FormatSpecifiable { public var _arg: UInt32 { UInt32(self) }; public var _specifier: String { "%u" } }
extension UInt16 : _FormatSpecifiable { public var _arg: UInt32 { UInt32(self) }; public var _specifier: String { "%u" } }
extension UInt32 : _FormatSpecifiable { public var _arg: UInt32 { self }; public var _specifier: String { "%u" } }
extension UInt64 : _FormatSpecifiable { public var _arg: UInt64 { self }; public var _specifier: String { "%llu" } }
extension Float : _FormatSpecifiable { public var _arg: Float { self }; public var _specifier: String { "%f" } }
extension Double : _FormatSpecifiable { public var _arg: Double { self }; public var _specifier: String { "%lf" } }
extension CGFloat : _FormatSpecifiable { public var _arg: CGFloat { self }; public var _specifier: String { "%lf" } }

extension LocalizedStringKey.StringInterpolation {
    public mutating func appendInterpolation<T>(_ value: T, specifier: String) where T : _FormatSpecifiable {
        appendInterpolation(String(format: specifier, value._arg))
    }
}

// MARK: - Images and alignment

extension Image {
    /// Symbol images are not drawn here, so their rendering mode changes nothing.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> Image { self }
}
extension HorizontalAlignment {
    /// Lists have no separators here: their edges are the row's.
    @available(iOS 16.0, macOS 13.0, *)
    public static let listRowSeparatorLeading: HorizontalAlignment = .leading
    @available(iOS 16.0, macOS 13.0, *)
    public static let listRowSeparatorTrailing: HorizontalAlignment = .trailing
}
