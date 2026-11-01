// GeometryReader and GeometryProxy, with the iOS 16.5 SDK's declarations. Views are evaluated
// before layout here, so a reader's content sees the frame the reader was last laid out in (an
// empty one, the first time); when layout gives it another, the graph updates (ViewGraph.swift).
import Foundation
import CoreFoundation
import UIKit

@frozen public struct GeometryReader<Content> : View where Content : View {
  public var content: (GeometryProxy) -> Content
  @inlinable public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {
        self.content = content
    }
  public static func _makeView(view: _GraphValue<GeometryReader<Content>>, inputs: _ViewInputs) -> _ViewOutputs {
    let path = inputs.path.child("geometry")
    // Before its first layout a reader is empty; layout then reports its real frame.
    let frame = inputs.graph?.geometry(at: path) ?? .zero
    let proxy = GeometryProxy(frame: frame)
    let child = Content._makeView(view: _GraphValue(value: view.value.content(proxy)), inputs: inputs.child("geometryContent"))
    let identity = inputs.graph?.nodeIdentity(at: path) ?? ""
    if let graph = inputs.graph {
      geometryReporters[identity] = { [weak graph] frame in graph?.reportGeometry(frame, at: path) }
    }
    // Several views lay out as a ZStack inside a reader.
    var content = child.renderedNode
    let views = content.list
    if views.count != 1 {
      content = RenderNode(kind: "zstack", children: views)
      content.horizontal = 0; content.vertical = 0
    }
    return _ViewOutputs(node: RenderNode(kind: "geometry", identity: identity, children: [content]))
  }
  public typealias Body = Swift.Never
}

public struct GeometryProxy {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  /// The reader's frame in the window.
  private let globalFrame: CGRect
  fileprivate init(frame: CGRect) { globalFrame = frame }
  public var size: CoreFoundation.CGSize {
    get { globalFrame.size }
  }
  public subscript<T>(anchor: Anchor<T>) -> T {
    get { _abiUnimplemented("GeometryProxy: public subscript<T>(anchor: Anchor<T>) -> T {") }
  }
  /// Darling lays content out inside the safe area already.
  public var safeAreaInsets: EdgeInsets {
    get { EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0) }
  }
  /// Named coordinate spaces are not tracked: they answer as the global one.
  public func frame(in coordinateSpace: CoordinateSpace) -> CoreFoundation.CGRect {
    if case .local = coordinateSpace { return CGRect(origin: .zero, size: globalFrame.size) }
    return globalFrame
  }
}
