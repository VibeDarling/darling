@usableFromInline final class ConcreteShapeStyleBox<S: ShapeStyle>: AnyShapeStyleBox {
    let style: S
    init(_ style: S) { self.style = style }
    override func apply(to shape: inout _ShapeStyle_Shape) { style._apply(to: &shape) }
}
@frozen public struct AnyShapeStyle: ShapeStyle {
    @usableFromInline @frozen struct Storage: Equatable {
        var box: AnyShapeStyleBox
        @usableFromInline static func == (lhs: Self, rhs: Self) -> Bool { lhs.box === rhs.box }
    }
    @usableFromInline var storage: Storage
    public init<S: ShapeStyle>(_ style: S) { storage = Storage(box: ConcreteShapeStyleBox(style)) }
    public func _apply(to shape: inout _ShapeStyle_Shape) { storage.box.apply(to: &shape) }
    public static func _apply(to type: inout _ShapeStyle_ShapeType) { type.isSupported = true }
}
