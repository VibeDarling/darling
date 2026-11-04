import Foundation
import UIKit

@frozen public struct EdgeInsets: Equatable {
    public var top, leading, bottom, trailing: CGFloat
    @inlinable public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top; self.leading = leading; self.bottom = bottom; self.trailing = trailing
    }
    @inlinable public init() { self.init(top: 0, leading: 0, bottom: 0, trailing: 0) }
    @usableFromInline init(_all value: CGFloat) { self.init(top: value, leading: value, bottom: value, trailing: value) }
}

@usableFromInline final class AnyImageProviderBox {
    enum Source: Equatable {
        case named(String, Bundle?)
        case system(String)
        case native(UIImage)
    }
    let source: Source
    var capInsets: EdgeInsets?
    var resizingMode = Image.ResizingMode.stretch
    var renderingMode: Image.TemplateRenderingMode?
    var interpolation = Image.Interpolation.medium
    var antialiased = true
    var label: Text?
    var decorative = false
    init(_ source: Source) { self.source = source }
    func copy() -> AnyImageProviderBox {
        let result = AnyImageProviderBox(source)
        result.capInsets = capInsets; result.resizingMode = resizingMode
        result.renderingMode = renderingMode; result.interpolation = interpolation
        result.antialiased = antialiased; result.label = label; result.decorative = decorative
        return result
    }
    static func equal(_ lhs: AnyImageProviderBox, _ rhs: AnyImageProviderBox) -> Bool {
        lhs.source == rhs.source && lhs.capInsets == rhs.capInsets && lhs.resizingMode == rhs.resizingMode &&
        lhs.renderingMode == rhs.renderingMode && lhs.interpolation == rhs.interpolation &&
        lhs.antialiased == rhs.antialiased && lhs.label == rhs.label && lhs.decorative == rhs.decorative
    }
}

@frozen public struct Image: Equatable {
    @usableFromInline var provider: AnyImageProviderBox
    public enum ResizingMode: Hashable { case tile, stretch }
    public enum TemplateRenderingMode: Hashable { case template, original }
    public enum Interpolation: Hashable { case none, low, medium, high }
    public static var _mainNamedBundle: Bundle?
    public init(_ name: String, bundle: Bundle? = nil) {
        provider = AnyImageProviderBox(.named(name, bundle ?? Self._mainNamedBundle))
    }
    public init(_ name: String, bundle: Bundle? = nil, label: Text) {
        self.init(name, bundle: bundle); provider.label = label
    }
    public init(decorative name: String, bundle: Bundle? = nil) {
        self.init(name, bundle: bundle); provider.decorative = true
    }
    public init(systemName: String) { provider = AnyImageProviderBox(.system(systemName)) }
    public init(_internalSystemName systemName: String) { self.init(systemName: systemName) }
    public init(uiImage: UIImage) { provider = AnyImageProviderBox(.native(uiImage)) }
    public static func == (lhs: Self, rhs: Self) -> Bool { AnyImageProviderBox.equal(lhs.provider, rhs.provider) }
    public func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: ResizingMode = .stretch) -> Self {
        var result = self; result.provider = provider.copy()
        result.provider.capInsets = capInsets; result.provider.resizingMode = resizingMode
        return result
    }
    public func renderingMode(_ mode: TemplateRenderingMode?) -> Self {
        var result = self; result.provider = provider.copy(); result.provider.renderingMode = mode; return result
    }
    public func interpolation(_ interpolation: Interpolation) -> Self {
        var result = self; result.provider = provider.copy(); result.provider.interpolation = interpolation; return result
    }
    public func antialiased(_ isAntialiased: Bool) -> Self {
        var result = self; result.provider = provider.copy(); result.provider.antialiased = isAntialiased; return result
    }
}

extension Image: View {
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let provider = view.value.provider
        var node = RenderNode(kind: "image")
        node.properties["foreground"] = ForegroundStyle().resolve(inputs).solidEncoded
        node.identity = inputs.graph?.nodeIdentity(at: inputs.path.child("image")) ?? ""
        switch provider.source {
        case let .named(name, bundle):
            node.image = UIImage(named: name, in: bundle ?? Bundle.main, compatibleWith: nil)
            node.properties["image-name"] = name
            node.properties["image-bundle"] = (bundle ?? Bundle.main).bundlePath
            if !provider.decorative { node.properties["label"] = name }
        case let .system(name):
            // Darling has no SF Symbols: a glyph in the current font and color stands in.
            if !provider.decorative {
                return Text._makeView(view: _GraphValue(value: Text(verbatim: _darlingSymbolGlyph(name))), inputs: inputs.child("symbol"))
            }
            node.properties["image-symbol"] = name
        case let .native(image): node.image = image
        }
        if let label = provider.label {
            node.properties["label"] = Text._makeView(view: _GraphValue(value: label), inputs: inputs).text
        }
        if provider.decorative { node.properties["hidden"] = "true" }
        if let insets = provider.capInsets {
            node.properties["image-resize"] = provider.resizingMode == .tile ? "tile" : "stretch"
            node.properties["image-insets"] = "\(insets.top),\(insets.leading),\(insets.bottom),\(insets.trailing)"
        }
        node.properties["image-interpolation"] = provider.interpolation == .none ? "nearest" : "linear"
        node.properties["image-antialiased"] = provider.antialiased ? "true" : "false"
        if let mode = provider.renderingMode { node.properties["image-rendering"] = mode == .template ? "template" : "original" }
        return _ViewOutputs(node: node)
    }
}

/// A Unicode stand-in for an SF Symbol, from its base name (without .fill, .circle and the like).
func _darlingSymbolGlyph(_ name: String) -> String {
    let glyphs: [String: String] = [
        "plus": "+", "minus": "\u{2212}", "xmark": "\u{2715}", "checkmark": "\u{2713}", "multiply": "\u{2715}",
        "chevron.right": "\u{203A}", "chevron.left": "\u{2039}", "chevron.down": "\u{2304}", "chevron.up": "\u{2303}",
        "chevron.forward": "\u{203A}", "chevron.backward": "\u{2039}", "chevron.up.chevron.down": "\u{2195}",
        "ellipsis": "\u{22EF}", "gear": "\u{2699}", "gearshape": "\u{2699}", "gearshape.2": "\u{2699}",
        "trash": "\u{232B}", "square.and.arrow.up": "\u{21EA}", "square.and.arrow.down": "\u{21E9}",
        "arrow.down": "\u{2193}", "arrow.up": "\u{2191}", "arrow.left": "\u{2190}", "arrow.right": "\u{2192}",
        "arrow.down.circle": "\u{2193}", "arrow.up.circle": "\u{2191}", "arrow.clockwise": "\u{21BB}",
        "arrow.counterclockwise": "\u{21BA}", "arrow.triangle.2.circlepath": "\u{21BB}",
        "magnifyingglass": "\u{2315}", "star": "\u{2605}", "heart": "\u{2665}", "info": "\u{24D8}",
        "info.circle": "\u{24D8}", "questionmark": "?", "questionmark.circle": "?", "exclamationmark": "!",
        "exclamationmark.triangle": "\u{26A0}", "exclamationmark.circle": "!", "doc": "\u{25A4}", "doc.text": "\u{25A4}",
        "doc.on.doc": "\u{2750}", "folder": "\u{25AD}", "globe": "\u{25CE}", "globe.desk": "\u{25CE}",
        "square.grid.2x2": "\u{25A6}", "app": "\u{25A2}", "app.badge": "\u{25A2}", "app.dashed": "\u{25A2}",
        "person": "\u{263A}", "person.2": "\u{263A}", "house": "\u{2302}", "key": "\u{26B7}", "lock": "\u{26BF}",
        "pencil": "\u{270E}", "square.and.pencil": "\u{270E}", "paintbrush": "\u{270E}", "paperplane": "\u{27A4}",
        "signature": "\u{270D}", "square.stack": "\u{2750}", "square.stack.3d.up": "\u{2750}",
        "list.bullet": "\u{2630}", "line.3.horizontal": "\u{2630}", "line.3.horizontal.decrease": "\u{2630}",
        "slider.horizontal.3": "\u{2637}", "cloud": "\u{2601}", "bolt": "\u{26A1}", "link": "\u{26D3}",
        "archivebox": "\u{25A3}", "shippingbox": "\u{25A3}", "tray": "\u{25AD}", "tray.and.arrow.down": "\u{21E9}",
        "square.and.arrow.down.on.square": "\u{21E9}", "hammer": "\u{2692}", "wrench": "\u{2692}",
        "wrench.and.screwdriver": "\u{2692}", "sparkles": "\u{2728}", "flag": "\u{2691}", "bell": "\u{237E}",
        "clock": "\u{25F7}", "calendar": "\u{25A6}", "photo": "\u{25A7}", "camera": "\u{25C9}",
        "eye": "\u{25C9}", "eye.slash": "\u{25CC}", "circle": "\u{25CB}", "square": "\u{25A1}",
    ]
    var base = name
    for suffix in [".fill", ".circle", ".square", ".rectangle", ".badge.plus", ".badge.minus"] {
        if let glyph = glyphs[base] { return glyph }
        if base.hasSuffix(suffix) { base.removeLast(suffix.count) }
    }
    return glyphs[base] ?? "\u{2022}"
}
