// The views Shape.stroke and strokeBorder return, from the iOS 18.0 SDK's SwiftUICore interface.
// Both are frozen: apps inline their initializers, so `view` and `shape` keep the SDK's order.

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public enum LayoutDirectionBehavior: Hashable, Sendable {
    case fixed
    case mirrors(in: LayoutDirection)
    public static var mirrors: LayoutDirectionBehavior { .mirrors(in: .rightToLeft) }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public protocol ShapeView<Content>: View {
    associatedtype Content: Shape
    var shape: Self.Content { get }
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension _ShapeView: ShapeView {}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@frozen public struct StrokeShapeView<Content, Style, Background>: ShapeView where Content: Shape, Style: ShapeStyle, Background: View {
    @usableFromInline internal typealias ViewType = ModifiedContent<_ShapeView<_StrokedShape<Content>, Style>, _BackgroundModifier<Background>>
    @usableFromInline internal var view: ViewType
    @_alwaysEmitIntoClient public var shape: Content {
        get { view.content.shape.shape }
        set { view.content.shape.shape = newValue }
    }
    @_alwaysEmitIntoClient public init(shape: Content, style: Style, strokeStyle: StrokeStyle, isAntialiased: Bool, background: Background) {
        view = .init(content: _ShapeView(shape: _StrokedShape(shape: shape, style: strokeStyle), style: style,
                                         fillStyle: .init(antialiased: isAntialiased)),
                     modifier: .init(background: background))
    }
    public static func _makeView(view: _GraphValue<StrokeShapeView<Content, Style, Background>>, inputs: _ViewInputs) -> _ViewOutputs {
        ViewType._makeView(view: _GraphValue(value: view.value.view), inputs: inputs)
    }
    public typealias Body = Never
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@frozen public struct StrokeBorderShapeView<Content, Style, Background>: ShapeView where Content: InsettableShape, Style: ShapeStyle, Background: View {
    @usableFromInline internal typealias ViewType = ModifiedContent<_ShapeView<_StrokedShape<Content.InsetShape>, Style>, _BackgroundModifier<Background>>
    public var shape: Content
    @usableFromInline internal var view: ViewType
    @_alwaysEmitIntoClient public init(shape: Content, style: Style, strokeStyle: StrokeStyle, isAntialiased: Bool, background: Background) {
        self.shape = shape
        view = .init(content: _ShapeView(shape: _StrokedShape(shape: shape.inset(by: strokeStyle.lineWidth * 0.5), style: strokeStyle),
                                         style: style, fillStyle: .init(antialiased: isAntialiased)),
                     modifier: .init(background: background))
    }
    public static func _makeView(view: _GraphValue<StrokeBorderShapeView<Content, Style, Background>>, inputs: _ViewInputs) -> _ViewOutputs {
        ViewType._makeView(view: _GraphValue(value: view.value.view), inputs: inputs)
    }
    public typealias Body = Never
}
