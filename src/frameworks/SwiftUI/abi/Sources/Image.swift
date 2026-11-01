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
        case let .system(name): node.properties["image-symbol"] = name
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
