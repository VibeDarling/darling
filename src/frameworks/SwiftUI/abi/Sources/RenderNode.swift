import Foundation
import UIKit

// Structured output shared by the local graph and the native UIKit presenter.
struct RenderNode {
    var kind: String
    var identity = ""
    var text = ""
    var children: [RenderNode] = []
    var spacing: Double = 8
    var horizontal = 1
    var vertical = 1
    var properties: [String: String] = [:]
    var image: UIImage?
    var shape: RuntimeShape?
    /// The UIKit view of a UIViewRepresentable or UIViewControllerRepresentable ("platform" nodes).
    var platformView: UIView?
    /// What a platform view asks for when proposed a size; nil means it fills the proposal.
    var platformSize: ((CGSize?) -> CGSize?)?
    var textClusters: [Int] = []
    var textRuns: [[String: Any]] = []

    var list: [RenderNode] {
        if kind == "empty" { return [] }
        if kind == "group" && properties.isEmpty { return children.flatMap(\.list) }
        return [self]
    }
    var plainText: String {
        if kind == "text" { return text }
        return children.map(\.plainText).filter { !$0.isEmpty }.joined(separator: kind == "hstack" ? " " : "\n")
    }
    var dictionary: NSDictionary {
        var values: [String: Any] = ["kind": kind, "identity": identity, "text": text,
            "children": children.map(\.dictionary), "spacing": spacing,
            "horizontal": horizontal, "vertical": vertical, "properties": properties, "text-runs": textRuns, "text-clusters": textClusters]
        if let image = image { values["image"] = image }
        if let shape = shape { values["shape"] = shape }
        return values._bridgeToObjectiveC()
    }
}
func sendRenderTree(_ output: _SceneOutputs) {
    var node = output.node ?? RenderNode(kind: output.text.isEmpty ? "empty" : "text", text: output.text)
    node.properties.merge(output.accessibility) { _, outer in outer }
    darlingSetTree(node)
}
