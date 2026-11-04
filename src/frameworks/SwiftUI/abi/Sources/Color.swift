import CoreFoundation
import Foundation
import UIKit
import Darwin

final class NativeColor: Hashable {
    let color: UIColor
    init(_ color: UIColor) { self.color = color }
    static func == (lhs: NativeColor, rhs: NativeColor) -> Bool { lhs.color === rhs.color }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(color)) }
    func resolve(_ scheme: ColorScheme, _ increasedContrast: Bool) -> ResolvedPaint {
        let values = UnsafeMutablePointer<Double>.allocate(capacity: 4)
        defer { values.deallocate() }
        resolveColor(color, scheme == .dark ? 2 : 1, increasedContrast ? 1 : 0, values)
        return ResolvedPaint(red: values[0], green: values[1], blue: values[2], opacity: values[3])
    }
}
@usableFromInline class AnyColorBox: AnyShapeStyleBox {
    enum Value: Hashable {
        case rgba(Color.RGBColorSpace, Double, Double, Double, Double)
        case primary
        case native(NativeColor)
        case systemBackground(Double)
        case secondary
        case asset(String, String)
        indirect case opacity(Value, Double)
    }
    let value: Value
    init(_ value: Value) { self.value = value }
    func resolve(_ scheme: ColorScheme = .light, _ increasedContrast: Bool = false) -> ResolvedPaint {
        func resolve(_ value: Value) -> ResolvedPaint {
            switch value {
            case let .rgba(space, red, green, blue, alpha):
                var r = red, g = green, b = blue
                func decode(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : Double(powf(Float((v + 0.055) / 1.055), 2.4)) }
                func encode(_ v: Double) -> Double { v <= 0.0031308 ? v * 12.92 : 1.055 * Double(powf(Float(v), 1 / 2.4)) - 0.055 }
                if space == .displayP3 {
                    let lr = decode(r), lg = decode(g), lb = decode(b)
                    r = encode(1.22494018 * lr - 0.22494018 * lg)
                    g = encode(-0.04205695 * lr + 1.04205695 * lg)
                    b = encode(-0.01963755 * lr - 0.07863605 * lg + 1.0982736 * lb)
                } else if space == .sRGBLinear { r = encode(r); g = encode(g); b = encode(b) }
                return ResolvedPaint(red: r, green: g, blue: b, opacity: alpha)
            case .native(let color): return color.resolve(scheme, increasedContrast)
            case .systemBackground(let alpha): return scheme == .dark ? ResolvedPaint(opacity: alpha) : ResolvedPaint(red: 1, green: 1, blue: 1, opacity: alpha)
            case .primary: return scheme == .dark ? ResolvedPaint(red: 1, green: 1, blue: 1) : ResolvedPaint()
            case .secondary: return scheme == .dark ? ResolvedPaint(red: 1, green: 1, blue: 1, opacity: 0.6) : ResolvedPaint(opacity: 0.6)
            case let .opacity(value, factor): return resolve(value).multipliedOpacity(factor)
            case let .asset(name, bundle):
                // As SwiftUI does, a color the catalog lacks is clear.
                guard let color = UIColor(named: name, in: Bundle(path: bundle), compatibleWith: nil) else { return ResolvedPaint(opacity: 0) }
                return NativeColor(color).resolve(scheme, increasedContrast)
            }
        }
        return resolve(value)
    }
}
private func colorComponents(_ color: UIColor, _ components: UnsafeMutablePointer<Double>) {
    for (i, value) in darlingColorComponents(color).enumerated() { components[i] = value }
}
private func isSystemBackground(_ color: UIColor) -> Int64 { darlingColorIsSystemBackground(color) ? 1 : 0 }
private func isDynamic(_ color: UIColor) -> Int64 { darlingColorIsDynamic(color) ? 1 : 0 }
private func resolveColor(_ color: UIColor, _ style: Int64, _ contrast: Int64, _ components: UnsafeMutablePointer<Double>) {
    for (i, value) in darlingResolveColor(color, dark: style == 2, increasedContrast: contrast != 0).enumerated() { components[i] = value }
}
@frozen public struct Color: Hashable, CustomStringConvertible {
    @usableFromInline var provider: AnyColorBox
    public enum RGBColorSpace: Hashable { case sRGB, sRGBLinear, displayP3 }
    public init(_ colorSpace: RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) {
        precondition(red.isFinite && green.isFinite && blue.isFinite && opacity.isFinite, "SwiftUI: nonfinite color components")
        provider = AnyColorBox(.rgba(colorSpace, red, green, blue, opacity))
    }
    public init(_ colorSpace: RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) {
        self.init(colorSpace, red: white, green: white, blue: white, opacity: opacity)
    }
    public init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) {
        precondition(hue.isFinite && saturation.isFinite && brightness.isFinite && opacity.isFinite)
        let h = (hue - hue.rounded(.down)) * 6
        let sector = Int(h), fraction = h - Double(sector)
        let p = brightness * (1 - saturation), q = brightness * (1 - saturation * fraction), t = brightness * (1 - saturation * (1 - fraction))
        let components = [(brightness, t, p), (q, brightness, p), (p, brightness, t),
                          (p, q, brightness), (t, p, brightness), (brightness, p, q)][sector % 6]
        self.init(red: components.0, green: components.1, blue: components.2, opacity: opacity)
    }
    public init(_ name: String, bundle: Bundle? = nil) {
        provider = AnyColorBox(.asset(name, (bundle ?? Bundle.main).bundlePath))
    }
    public init(uiColor: UIColor) {
        if isDynamic(uiColor) != 0 { self.init(.native(NativeColor(uiColor))); return }
        let values = UnsafeMutablePointer<Double>.allocate(capacity: 4)
        defer { values.deallocate() }
        colorComponents(uiColor, values)
        self.init(red: values[0], green: values[1], blue: values[2], opacity: values[3])
        if isSystemBackground(uiColor) != 0 { provider = AnyColorBox(.systemBackground(values[3])) }
    }
    public init(_ color: UIColor) { self.init(uiColor: color) }
    private init(_ value: AnyColorBox.Value) { provider = AnyColorBox(value) }
    public func opacity(_ opacity: Double) -> Self {
        precondition(opacity.isFinite)
        return Self(.opacity(provider.value, opacity))
    }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.provider.value == rhs.provider.value }
    public func hash(into hasher: inout Hasher) { hasher.combine(provider.value) }
    public var description: String { provider.resolve().encoded }
    public static let black = Self(white: 0)
    public static let white = Self(white: 1)
    public static let clear = Self(white: 0, opacity: 0)
    public static let gray = Self(red: 0.5569, green: 0.5569, blue: 0.5765)
    public static let red = Self(red: 1, green: 0.2314, blue: 0.1882)
    public static let orange = Self(red: 1, green: 0.5843, blue: 0)
    public static let yellow = Self(red: 1, green: 0.8, blue: 0)
    public static let green = Self(red: 0.2039, green: 0.7804, blue: 0.349)
    public static let mint = Self(red: 0, green: 0.7804, blue: 0.7451)
    public static let teal = Self(red: 0.1882, green: 0.6902, blue: 0.7804)
    public static let cyan = Self(red: 0.1961, green: 0.6784, blue: 0.902)
    public static let blue = Self(red: 0, green: 0.4784, blue: 1)
    /// The system blue: Darling does not read an app's AccentColor asset.
    public static var accentColor: Color { blue }
    public static let indigo = Self(red: 0.3451, green: 0.3373, blue: 0.8392)
    public static let purple = Self(red: 0.6863, green: 0.3216, blue: 0.8706)
    public static let pink = Self(red: 1, green: 0.1765, blue: 0.3333)
    public static let brown = Self(red: 0.6353, green: 0.5176, blue: 0.3686)
    public static let primary = Self(.primary)
    public static let secondary = Self(.secondary)
}
extension Color: ShapeStyle {
    public func _apply(to shape: inout _ShapeStyle_Shape) { shape.result = provider.resolve(shape.colorScheme, shape.increasedContrast) }
    public static func _apply(to type: inout _ShapeStyle_ShapeType) { type.isSupported = true }
}
extension Color: View {
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        var node = RenderNode(kind: "color")
        node.identity = inputs.graph?.nodeIdentity(at: inputs.path.child("color")) ?? ""
        node.properties["foreground"] = view.value.resolve(inputs).encoded
        return _ViewOutputs(node: node)
    }
}
private final class TextStyleModifier<Style: ShapeStyle>: AnyTextModifier {
    let style: Style
    init(_ style: Style) { self.style = style }
    override func paint(_ inputs: _ViewInputs) -> ResolvedPaint { style.resolve(inputs) }
}
extension Text {
    public func foregroundColor(_ color: Color?) -> Self {
        var result = self; result.modifiers.append(.color(color)); return result
    }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> Self {
        var result = self; result.modifiers.append(.anyTextModifier(TextStyleModifier(style))); return result
    }
}
