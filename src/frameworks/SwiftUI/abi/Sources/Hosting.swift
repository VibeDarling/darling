// UIHostingController: a view controller showing a SwiftUI view inside a UIKit app. Each one has its
// own view graph, which re-renders into the controller's host view when the view's state changes.
// The members are the iOS 16.5 SDK's, so apps (and their subclasses) link against them.
import Foundation
import CoreFoundation
import UIKit

@preconcurrency @MainActor open class UIHostingController<Content> : UIKit.UIViewController where Content : View {
  private var content: Content
  private let graph = ViewGraph()
  private var host: HostView?
  private var options: UIHostingControllerSizingOptions = []
  private var safeAreaDisabled = false

  @preconcurrency @MainActor @objc override dynamic open var keyCommands: [UIKit.UIKeyCommand]? {
    @objc get { nil }
  }
  @preconcurrency @MainActor public init(rootView: Content) {
    content = rootView
    super.init(nibName: nil, bundle: nil)
    connectGraph()
  }
  @preconcurrency @MainActor public init?(coder aDecoder: Foundation.NSCoder, rootView: Content) {
    content = rootView
    super.init(coder: aDecoder)
    connectGraph()
  }
  /// As in SwiftUI, a hosting controller can't be decoded without its root view.
  @preconcurrency @MainActor @objc required dynamic public init?(coder aDecoder: Foundation.NSCoder) { return nil }

  private func connectGraph() {
    let graph = self.graph
    graph.render = { [unowned self] in
      var inputs = _ViewInputs(graph: graph)
      inputs.environment.scenePhase = graph.phase
      let output = Content._makeView(view: _GraphValue(value: self.content), inputs: inputs.child("hosted"))
      return _SceneOutputs(text: output.text, accessibility: output.accessibility, node: output.renderedNode)
    }
    graph.refresh = { [weak self] in self?.update() }
  }

  /// Evaluates the graph and shows the result.
  private func update() {
    let output = graph.update()
    var node = output.node ?? RenderNode(kind: output.text.isEmpty ? "empty" : "text", text: output.text)
    node.properties.merge(output.accessibility) { _, outer in outer }
    if safeAreaDisabled { node.properties["ignores-safe-area"] = "true" }
    darlingDumpTree(node, "SwiftUI hosted tree")
    host?.tree = node
    host?.render()
  }

  @preconcurrency @MainActor @objc override dynamic open func loadView() {
    let view = HostView(frame: UIScreen.main.bounds)
    view.backgroundColor = UIColor.white
    host = view
    self.view = view
    graph.launch()
  }
  @preconcurrency @MainActor @objc override dynamic open func viewWillAppear(_ animated: Swift.Bool) { super.viewWillAppear(animated) }
  @preconcurrency @MainActor @objc override dynamic open func viewDidAppear(_ animated: Swift.Bool) { super.viewDidAppear(animated) }
  @preconcurrency @MainActor @objc override dynamic open func viewWillDisappear(_ animated: Swift.Bool) { super.viewWillDisappear(animated) }
  @preconcurrency @MainActor @objc override dynamic open func viewDidDisappear(_ animated: Swift.Bool) { super.viewDidDisappear(animated) }
  @preconcurrency @MainActor @objc override dynamic open func viewWillLayoutSubviews() { super.viewWillLayoutSubviews() }
  @preconcurrency @MainActor @objc override dynamic open var isModalInPresentation: Swift.Bool {
    @objc get { false }
    @objc set {}
  }
  @preconcurrency @MainActor public var rootView: Content {
    get { content }
    set { content = newValue; graph.invalidate("rootView") }
  }
  @available(iOS 16.0, tvOS 16.0, *)
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  @preconcurrency @MainActor public var sizingOptions: UIHostingControllerSizingOptions {
    get { options }
    set { options = newValue }
  }
  /// The size the root view takes when proposed `size`.
  @preconcurrency @MainActor public func sizeThatFits(in size: CoreFoundation.CGSize) -> CoreFoundation.CGSize {
    loadViewIfNeeded()
    if host?.tree == nil { update() }
    return host?.fittingSize(proposing: size) ?? .zero
  }
  @preconcurrency @MainActor public func _render(seconds: Swift.Double) { update() }
  @preconcurrency @MainActor public func _forEachIdentifiedView(body: (_IdentifiedViewProxy) -> Swift.Void) {}
  @available(iOS, introduced: 13.0, deprecated: 16.4, message: "Use UIHostingController/safeAreaRegions or _UIHostingView/safeAreaRegions")
  @available(macOS, unavailable)
  @available(tvOS, introduced: 13.0, deprecated: 16.4, message: "Use UIHostingController/safeAreaRegions or _UIHostingView/safeAreaRegions")
  @available(watchOS, introduced: 6.0, deprecated: 9.4, message: "Use UIHostingController/safeAreaRegions or _UIHostingView/safeAreaRegions")
  @preconcurrency @MainActor public var _disableSafeArea: Swift.Bool {
    get { safeAreaDisabled }
    set { safeAreaDisabled = newValue; graph.invalidate("_disableSafeArea") }
  }
  @preconcurrency @MainActor @objc override dynamic open func preferredContentSizeDidChange(forChildContentContainer container: any UIKit.UIContentContainer) {}
  @preconcurrency @MainActor @objc override dynamic open var preferredStatusBarStyle: UIKit.UIStatusBarStyle {
    @objc get { .default }
  }
  @preconcurrency @MainActor @objc override dynamic open var prefersStatusBarHidden: Swift.Bool {
    @objc get { false }
  }
  @preconcurrency @MainActor @objc override dynamic open var preferredStatusBarUpdateAnimation: UIKit.UIStatusBarAnimation {
    @objc get { .fade }
  }
  @preconcurrency @MainActor @objc override dynamic open var childForStatusBarStyle: UIKit.UIViewController? {
    @objc get { nil }
  }
  @preconcurrency @MainActor @objc override dynamic open var childForStatusBarHidden: UIKit.UIViewController? {
    @objc get { nil }
  }
  @preconcurrency @MainActor @objc override dynamic open func viewWillTransition(to size: CoreFoundation.CGSize, with coordinator: any UIKit.UIViewControllerTransitionCoordinator) {}
  @preconcurrency @MainActor @objc override dynamic open func willMove(toParent parent: UIKit.UIViewController?) { super.willMove(toParent: parent) }
  @preconcurrency @MainActor @objc override dynamic open func didMove(toParent parent: UIKit.UIViewController?) { super.didMove(toParent: parent) }
  @preconcurrency @MainActor @objc override dynamic open var preferredScreenEdgesDeferringSystemGestures: UIKit.UIRectEdge {
    @objc get { [] }
  }
  @preconcurrency @MainActor @objc override dynamic open var childForScreenEdgesDeferringSystemGestures: UIKit.UIViewController? {
    @objc get { nil }
  }
  @preconcurrency @MainActor @objc override dynamic open var prefersHomeIndicatorAutoHidden: Swift.Bool {
    @objc get { false }
  }
  @preconcurrency @MainActor @objc override dynamic open var childForHomeIndicatorAutoHidden: UIKit.UIViewController? {
    @objc get { nil }
  }
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  @preconcurrency @MainActor final public var _rendererConfiguration: _RendererConfiguration {
    get { _abiUnimplemented("UIHostingController._rendererConfiguration") }
    set {}
  }
  @preconcurrency @MainActor final public var _rendererObject: Swift.AnyObject? {
    get { nil }
  }
  @preconcurrency @MainActor @objc override dynamic open func target(forAction action: ObjectiveC.Selector, withSender sender: Any?) -> Any? {
    super.target(forAction: action, withSender: sender)
  }
  @objc deinit {}
}

extension UIHostingController : _UIHostingViewable where Content == AnyView {
}
