import CoreFoundation
import CoreText

struct FontDescriptor: Hashable {
    enum Size: Hashable { case fixed(CGFloat), style(Font.TextStyle) }
    var size: Size
    var weight: Font.Weight?
    var design: Font.Design?
    var italic = false
    var monospacedDigits = false
    /// A custom font's name (PostScript or family), for Font.custom and Font(CTFont).
    var name: String? = nil
    var pointSize: CGFloat {
        switch size {
        case .fixed(let value): return value
        case .style(let style):
            switch style {
            case .largeTitle: return 34
            case .title: return 28
            case .title2: return 22
            case .title3: return 20
            case .headline, .body: return 17
            case .subheadline: return 15
            case .callout: return 16
            case .footnote: return 13
            case .caption: return 12
            case .caption2: return 11
            }
        }
    }
    var defaultWeight: Font.Weight { if case .style(.headline) = size { return .semibold }; return .regular }
}
extension Font {
    public enum Design: Hashable { case `default`, serif, rounded, monospaced }
    public static func system(size: CGFloat, weight: Weight? = nil, design: Design? = nil) -> Font {
        precondition(size.isFinite && size > 0, "SwiftUI: invalid font size")
        return Font(FontDescriptor(size: .fixed(size), weight: weight, design: design))
    }
    @_disfavoredOverload public static func system(size: CGFloat, weight: Weight = .regular, design: Design = .default) -> Font {
        system(size: size, weight: Optional(weight), design: Optional(design))
    }
    public static func system(_ style: TextStyle, design: Design? = nil, weight: Weight? = nil) -> Font {
        Font(FontDescriptor(size: .style(style), weight: weight, design: design))
    }
    @_disfavoredOverload public static func system(_ style: TextStyle, design: Design = .default) -> Font { system(style, design: Optional(design), weight: nil) }
    private init(_ descriptor: FontDescriptor) { provider = AnyFontBox(descriptor) }
    private func modified(_ action: (inout FontDescriptor) -> Void) -> Font { var descriptor = provider.value; action(&descriptor); return Font(descriptor) }
    public func weight(_ weight: Weight) -> Font { modified { $0.weight = weight } }
    public func italic() -> Font { modified { $0.italic = true } }
    public func bold() -> Font { weight(.bold) }
    public func monospacedDigit() -> Font { modified { $0.monospacedDigits = true } }
    public func monospaced() -> Font { modified { $0.design = .monospaced } }
    public static func custom(_ name: String, size: CGFloat) -> Font {
        Font(FontDescriptor(size: .fixed(size), name: name))
    }
    /// Dynamic Type is not scaled here, so a size relative to a text style is the size itself.
    public static func custom(_ name: String, size: CGFloat, relativeTo textStyle: TextStyle) -> Font { custom(name, size: size) }
    public static func _custom(_ name: String, size: CGFloat, textStyle: TextStyle) -> Font { custom(name, size: size) }
    public static func custom(_ name: String, fixedSize: CGFloat) -> Font { custom(name, size: fixedSize) }
    public static func _custom(_ name: String, verbatimSize: CGFloat) -> Font { custom(name, size: verbatimSize) }
    public init(_ font: CTFont) {
        self.init(FontDescriptor(size: .fixed(CTFontGetSize(font)), name: CTFontCopyPostScriptName(font) as String))
    }
    public static let largeTitle = system(.largeTitle)
    public static let title = system(.title)
    public static let title2 = system(.title2)
    public static let title3 = system(.title3)
    public static let headline = system(.headline)
    public static let subheadline = system(.subheadline)
    public static let body = system(.body)
    public static let callout = system(.callout)
    public static let footnote = system(.footnote)
    public static let caption = system(.caption)
    public static let caption2 = system(.caption2)
}
extension Font.Weight {
    // CoreText weight coordinates, also used by the SDK-frozen Weight value.
    public static let ultraLight = Self(value: -0.8)
    public static let thin = Self(value: -0.6)
    public static let light = Self(value: -0.4)
    public static let regular = Self(value: 0)
    public static let medium = Self(value: 0.23)
    public static let semibold = Self(value: 0.3)
    public static let bold = Self(value: 0.4)
    public static let heavy = Self(value: 0.56)
    public static let black = Self(value: 0.62)
}
