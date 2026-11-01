// Frozen storage follows the iOS SDK. Native layout handles the built-in
// alignments; custom AlignmentID guides and Layout protocol APIs are separate.
import CoreFoundation

@usableFromInline @frozen struct AlignmentKey: Equatable {
    @usableFromInline let bits: UInt
    @usableFromInline init(_ bits: UInt) { self.bits = bits }
    @usableFromInline static func == (lhs: Self, rhs: Self) -> Bool { lhs.bits == rhs.bits }
}
@frozen public struct HorizontalAlignment: Equatable {
    @usableFromInline let key: AlignmentKey
    @usableFromInline init(_ value: UInt) { key = AlignmentKey(value) }
    public static let leading = Self(0)
    public static let center = Self(1)
    public static let trailing = Self(2)
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.key == rhs.key }
}
@frozen public struct VerticalAlignment: Equatable {
    @usableFromInline let key: AlignmentKey
    @usableFromInline init(_ value: UInt) { key = AlignmentKey(value) }
    public static let top = Self(0)
    public static let center = Self(1)
    public static let bottom = Self(2)
    public static let firstTextBaseline = Self(3)
    public static let lastTextBaseline = Self(4)
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.key == rhs.key }
}
@frozen public struct Alignment: Equatable {
    public var horizontal: HorizontalAlignment
    public var vertical: VerticalAlignment
    @inlinable public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal; self.vertical = vertical
    }
    public static let center = Self(horizontal: .center, vertical: .center)
    public static let leading = Self(horizontal: .leading, vertical: .center)
    public static let trailing = Self(horizontal: .trailing, vertical: .center)
    public static let top = Self(horizontal: .center, vertical: .top)
    public static let bottom = Self(horizontal: .center, vertical: .bottom)
    public static let topLeading = Self(horizontal: .leading, vertical: .top)
    public static let topTrailing = Self(horizontal: .trailing, vertical: .top)
    public static let bottomLeading = Self(horizontal: .leading, vertical: .bottom)
    public static let bottomTrailing = Self(horizontal: .trailing, vertical: .bottom)
}

public protocol _VariadicView_Root { static var _viewListOptions: Int { get } }
extension _VariadicView_Root { public static var _viewListOptions: Int { 0 } }
public enum _VariadicView {
    public typealias Root = _VariadicView_Root
    @frozen public struct Tree<Root: _VariadicView_Root, Content> {
        public var root: Root
        public var content: Content
        @usableFromInline init(root: Root, content: Content) { self.root = root; self.content = content }
        @inlinable public init(_ root: Root, @ViewBuilder content: () -> Content) {
            self.root = root; self.content = content()
        }
    }
}

@frozen public struct _VStackLayout: _VariadicView_Root {
    public var alignment: HorizontalAlignment
    public var spacing: CGFloat?
    @inlinable public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil) { self.alignment = alignment; self.spacing = spacing }
}
@frozen public struct VStack<Content: View>: View {
    @usableFromInline var _tree: _VariadicView.Tree<_VStackLayout, Content>
    @inlinable public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        _tree = .init(root: _VStackLayout(alignment: alignment, spacing: spacing), content: content())
    }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let root = view.value._tree.root
        var childInputs = inputs.child("VStack")
        childInputs.stackAxis = "vertical"
        let child = Content._makeView(view: _GraphValue(value: view.value._tree.content), inputs: childInputs)
        return _ViewOutputs(node: RenderNode(kind: "vstack", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("vstack")) ?? "", children: child.renderedNode.list,
                                             spacing: Double(root.spacing ?? 8), horizontal: Int(root.alignment.key.bits), vertical: 1))
    }
}

@frozen public struct _HStackLayout: _VariadicView_Root {
    public var alignment: VerticalAlignment
    public var spacing: CGFloat?
    @inlinable public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) { self.alignment = alignment; self.spacing = spacing }
}
@frozen public struct HStack<Content: View>: View {
    @usableFromInline var _tree: _VariadicView.Tree<_HStackLayout, Content>
    @inlinable public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        _tree = .init(root: _HStackLayout(alignment: alignment, spacing: spacing), content: content())
    }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let root = view.value._tree.root
        var childInputs = inputs.child("HStack")
        childInputs.stackAxis = "horizontal"
        let child = Content._makeView(view: _GraphValue(value: view.value._tree.content), inputs: childInputs)
        return _ViewOutputs(node: RenderNode(kind: "hstack", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("hstack")) ?? "", children: child.renderedNode.list,
                                             spacing: Double(root.spacing ?? 8), horizontal: 1, vertical: Int(root.alignment.key.bits)))
    }
}

@frozen public struct _ZStackLayout: _VariadicView_Root {
    public var alignment: Alignment
    @inlinable public init(alignment: Alignment = .center) { self.alignment = alignment }
}
@frozen public struct ZStack<Content: View>: View {
    @usableFromInline var _tree: _VariadicView.Tree<_ZStackLayout, Content>
    @inlinable public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        _tree = .init(root: _ZStackLayout(alignment: alignment), content: content())
    }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let root = view.value._tree.root
        let child = Content._makeView(view: _GraphValue(value: view.value._tree.content), inputs: inputs.child("ZStack"))
        return _ViewOutputs(node: RenderNode(kind: "zstack", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("zstack")) ?? "", children: child.renderedNode.list,
                                             spacing: 0, horizontal: Int(root.alignment.horizontal.key.bits), vertical: Int(root.alignment.vertical.key.bits)))
    }
}
