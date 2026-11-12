// Custom layouts (the Layout protocol): a "layout" node keeps the app's layout, which sizes the node
// and places its children through LayoutSubview proxies over the host's measuring.
import Foundation
import CoreFoundation

struct LayoutPlacement {
    var position: CGPoint
    var anchor: UnitPoint
    var proposal: ProposedViewSize
}

/// One measuring and placing of a layout's children, shared by their subview proxies.
final class LayoutPass {
    let measure: (Int, ProposedViewSize) -> CGSize
    var placements: [Int: LayoutPlacement] = [:]
    init(measure: @escaping (Int, ProposedViewSize) -> CGSize) { self.measure = measure }
    func subviews(count: Int) -> LayoutSubviews {
        LayoutSubviews((0..<count).map { index in
            var subview = LayoutSubview(_abiTag: 0)
            subview.pass = self; subview.index = index
            return subview
        })
    }
}

/// An app's layout, with its type and cache hidden. The cache lasts one measuring or placing.
final class RuntimeLayout {
    let sizeThatFits: (ProposedViewSize, LayoutSubviews) -> CGSize
    let placeSubviews: (CGRect, ProposedViewSize, LayoutSubviews) -> Void
    init<L: Layout>(_ layout: L) {
        sizeThatFits = { proposal, subviews in
            var cache = layout.makeCache(subviews: subviews)
            return layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
        }
        placeSubviews = { bounds, proposal, subviews in
            var cache = layout.makeCache(subviews: subviews)
            layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cache)
        }
    }
}

protocol DarlingLayoutRoot {
    func makeOutput(children: [RenderNode], inputs: _ViewInputs) -> _ViewOutputs
}
extension _LayoutRoot: DarlingLayoutRoot {
    func makeOutput(children: [RenderNode], inputs: _ViewInputs) -> _ViewOutputs { makeLayoutOutput(self, children: children, inputs: inputs) }
}
func makeLayoutOutput<L: Layout>(_ root: _LayoutRoot<L>, children: [RenderNode], inputs: _ViewInputs) -> _ViewOutputs {
    var node = RenderNode(kind: "layout", identity: inputs.graph?.nodeIdentity(at: inputs.path.child("layout")) ?? "", children: children)
    node.layout = RuntimeLayout(root.layout)
    return _ViewOutputs(node: node)
}

/// Where an alignment guide (by its key's bits: leading, center, trailing, then the baselines) falls.
func guidePosition(_ bits: UInt, _ length: CGFloat) -> CGFloat {
    bits == 0 ? 0 : bits == 1 ? length / 2 : length
}
