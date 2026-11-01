// Hand-written companions of ABIGenerated.swift: declarations the SDK interface implies but does not
// spell out where the generator can see them.

extension Never: Gesture {
    public typealias Value = Never
    public static func _makeGesture(gesture: _GraphValue<Never>, inputs: _GestureInputs) -> _GestureOutputs<Never> {
        _abiUnimplemented("Never._makeGesture")
    }
}

extension _VariadicView {
    public typealias UnaryViewRoot = _VariadicView_UnaryViewRoot
}

// The SDK's primitive gestures, scenes and shape styles get `body` from internal extensions.
extension Gesture where Body == Never {
    public var body: Never { _abiUnimplemented("\(Self.self).body") }
}
extension Scene where Body == Never {
    public var body: Never { _abiUnimplemented("\(Self.self).body") }
}

extension _VariadicView {
    public typealias Children = _VariadicView_Children
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public typealias TimelineViewDefaultContext = TimelineView<EveryMinuteTimelineSchedule, Never>.Context

// Gradients and other shape styles are views that fill a rectangle.
extension ShapeStyle where Self: View, Self.Body == _ShapeView<Rectangle, Self> {
    public var body: _ShapeView<Rectangle, Self> { _ShapeView(shape: Rectangle(), style: self) }
}
extension _VariadicView.Tree: View where Root: _VariadicView_ViewRoot, Content: View {
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        _abiUnimplemented("_VariadicView.Tree<\(Root.self)>._makeView")
    }
}
extension ModifiedContent: DynamicViewContent where Content: DynamicViewContent, Modifier: ViewModifier {
    public var data: Content.Data { content.data }
}
extension ToolbarContent where Body == Never {
    public var body: Never { _abiUnimplemented("\(Self.self).body") }
}

extension Text {
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public struct LineStyle: Hashable {
        @usableFromInline internal var pattern: Pattern
        @usableFromInline internal var color: Color?
        public init(pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) {
            self.pattern = pattern
            self.color = color
        }
        public struct Pattern {
            @usableFromInline internal var _abiTag: Int
            public static let solid = Pattern(_abiTag: 0)
            public static let dot = Pattern(_abiTag: 1)
            public static let dash = Pattern(_abiTag: 2)
            public static let dashDot = Pattern(_abiTag: 3)
            public static let dashDotDot = Pattern(_abiTag: 4)
        }
        public static let single = LineStyle()
        public func hash(into hasher: inout Hasher) { hasher.combine(pattern._abiTag) }
        public static func == (a: Text.LineStyle, b: Text.LineStyle) -> Bool { a.pattern._abiTag == b.pattern._abiTag && a.color == b.color }
    }
}

extension Transaction {
    /// Darling's SwiftUI does not animate, so a transaction never carries animations to disable.
    public var disablesAnimations: Bool {
        get { false }
        set {}
    }
}

extension Transaction {
    /// The animation a change runs with. Darling's SwiftUI applies changes without animating.
    public var animation: Animation? {
        get { nil }
        set {}
    }
}
