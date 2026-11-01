// UIViewRepresentable and UIViewControllerRepresentable: an app's UIKit views and view controllers
// inside a SwiftUI hierarchy. Each keeps its view (or controller) and coordinator at its position in
// the graph, from makeUIView to dismantleUIView, and is placed by the renderer as a "platform" node.
// The requirements are the SDK's, including the underscored ones apps' conformances bind to.
import CoreFoundation
import UIKit

public struct _PlatformViewRepresentableLayoutOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
}

/// What a representable keeps between updates.
private final class PlatformViewState<Representable, Platform: AnyObject, Coordinator> {
    var platform: Platform?
    var coordinator: Coordinator?
    var dismantle: (() -> Void)?
    deinit { dismantle?() }
}

/// The view controller that SwiftUI's presenter shows, which representable controllers become children of.
var darlingHostViewController: UIViewController?

public protocol UIViewRepresentable: View where Self.Body == Never {
    associatedtype UIViewType: UIView
    func makeUIView(context: Self.Context) -> Self.UIViewType
    func updateUIView(_ uiView: Self.UIViewType, context: Self.Context)
    static func dismantleUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator)
    associatedtype Coordinator = Void
    func makeCoordinator() -> Self.Coordinator
    func _identifiedViewTree(in uiView: Self.UIViewType) -> _IdentifiedViewTree
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: Self.UIViewType, context: Self.Context) -> CGSize?
    func _overrideSizeThatFits(_ size: inout CGSize, in proposedSize: _ProposedSize, uiView: Self.UIViewType)
    func _overrideLayoutTraits(_ layoutTraits: inout _LayoutTraits, for uiView: Self.UIViewType)
    static func _modifyBridgedViewInputs(_ inputs: inout _ViewInputs)
    static func _layoutOptions(_ provider: Self.UIViewType) -> _PlatformViewRepresentableLayoutOptions
    typealias Context = UIViewRepresentableContext<Self>
}

extension UIViewRepresentable where Self.Coordinator == () {
    public func makeCoordinator() -> Self.Coordinator { () }
}

extension UIViewRepresentable {
    public func _resetUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator, destroy: () -> Void) { destroy() }
    public static func dismantleUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator) {}
    public func _identifiedViewTree(in uiView: Self.UIViewType) -> _IdentifiedViewTree { .empty }
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: Self.UIViewType, context: Self.Context) -> CGSize? { nil }
    public func _overrideSizeThatFits(_ size: inout CGSize, in proposedSize: _ProposedSize, uiView: Self.UIViewType) {}
    public func _overrideLayoutTraits(_ layoutTraits: inout _LayoutTraits, for uiView: Self.UIViewType) {}
    public static func _modifyBridgedViewInputs(_ inputs: inout _ViewInputs) {}
    public static func _layoutOptions(_ provider: Self.UIViewType) -> _PlatformViewRepresentableLayoutOptions { [] }
    public var body: Never { fatalError("\(Self.self).body: a UIViewRepresentable has no body") }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let representable = view.value
        let path = inputs.path.child("platform-view")
        let state = inputs.graph?.location(at: path) { PlatformViewState<Self, UIViewType, Coordinator>() }.get()
            ?? PlatformViewState<Self, UIViewType, Coordinator>()
        let coordinator = state.coordinator ?? representable.makeCoordinator()
        state.coordinator = coordinator
        let context = UIViewRepresentableContext<Self>(coordinator: coordinator, environment: inputs.environment)
        let uiView: UIViewType
        if let existing = state.platform {
            uiView = existing
        } else {
            uiView = representable.makeUIView(context: context)
            state.platform = uiView
            state.dismantle = { [weak uiView] in if let uiView = uiView { Self.dismantleUIView(uiView, coordinator: coordinator) } }
        }
        representable.updateUIView(uiView, context: context)
        var node = RenderNode(kind: "platform", identity: inputs.graph?.nodeIdentity(at: path) ?? "")
        node.platformView = uiView
        node.platformSize = { proposal in
            representable.sizeThatFits(ProposedViewSize(width: proposal?.width, height: proposal?.height), uiView: uiView, context: context)
        }
        return _ViewOutputs(node: node)
    }
    public static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        _ViewListOutputs(view: _makeView(view: view, inputs: inputs.viewInputs))
    }
}

public struct UIViewRepresentableContext<Representable> where Representable: UIViewRepresentable {
    public let coordinator: Representable.Coordinator
    public var transaction: Transaction { Transaction() }
    public var environment: EnvironmentValues
    init(coordinator: Representable.Coordinator, environment: EnvironmentValues) {
        self.coordinator = coordinator
        self.environment = environment
    }
}

public protocol UIViewControllerRepresentable: View where Self.Body == Never {
    associatedtype UIViewControllerType: UIViewController
    func makeUIViewController(context: Self.Context) -> Self.UIViewControllerType
    func updateUIViewController(_ uiViewController: Self.UIViewControllerType, context: Self.Context)
    static func dismantleUIViewController(_ uiViewController: Self.UIViewControllerType, coordinator: Self.Coordinator)
    associatedtype Coordinator = Void
    func makeCoordinator() -> Self.Coordinator
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: Self.UIViewControllerType, context: Self.Context) -> CGSize?
    func _identifiedViewTree(in uiViewController: Self.UIViewControllerType) -> _IdentifiedViewTree
    static func _layoutOptions(_ provider: Self.UIViewControllerType) -> _PlatformViewRepresentableLayoutOptions
    typealias Context = UIViewControllerRepresentableContext<Self>
}

extension UIViewControllerRepresentable where Self.Coordinator == () {
    public func makeCoordinator() -> Self.Coordinator { () }
}

extension UIViewControllerRepresentable {
    public func _resetUIViewController(_ uiViewController: Self.UIViewControllerType, coordinator: Self.Coordinator, destroy: () -> Void) { destroy() }
    public func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: Self.UIViewControllerType, context: Self.Context) -> CGSize? { nil }
    public static func dismantleUIViewController(_ uiViewController: Self.UIViewControllerType, coordinator: Self.Coordinator) {}
    public func _identifiedViewTree(in uiViewController: Self.UIViewControllerType) -> _IdentifiedViewTree { .empty }
    public static func _layoutOptions(_ provider: Self.UIViewControllerType) -> _PlatformViewRepresentableLayoutOptions { [] }
    public var body: Never { fatalError("\(Self.self).body: a UIViewControllerRepresentable has no body") }

    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let representable = view.value
        let path = inputs.path.child("platform-controller")
        let state = inputs.graph?.location(at: path) { PlatformViewState<Self, UIViewControllerType, Coordinator>() }.get()
            ?? PlatformViewState<Self, UIViewControllerType, Coordinator>()
        let coordinator = state.coordinator ?? representable.makeCoordinator()
        state.coordinator = coordinator
        let context = UIViewControllerRepresentableContext<Self>(coordinator: coordinator, environment: inputs.environment)
        let controller: UIViewControllerType
        if let existing = state.platform {
            controller = existing
        } else {
            controller = representable.makeUIViewController(context: context)
            state.platform = controller
            if let host = darlingHostViewController {
                host.addChild(controller)
                controller.didMove(toParent: host)
            }
            state.dismantle = { [weak controller] in
                guard let controller = controller else { return }
                controller.willMove(toParent: nil)
                controller.removeFromParent()
                Self.dismantleUIViewController(controller, coordinator: coordinator)
            }
        }
        representable.updateUIViewController(controller, context: context)
        var node = RenderNode(kind: "platform", identity: inputs.graph?.nodeIdentity(at: path) ?? "")
        node.platformView = controller.view
        node.platformSize = { proposal in
            representable.sizeThatFits(ProposedViewSize(width: proposal?.width, height: proposal?.height), uiViewController: controller, context: context)
        }
        return _ViewOutputs(node: node)
    }
    public static func _makeViewList(view: _GraphValue<Self>, inputs: _ViewListInputs) -> _ViewListOutputs {
        _ViewListOutputs(view: _makeView(view: view, inputs: inputs.viewInputs))
    }
}

public struct UIViewControllerRepresentableContext<Representable> where Representable: UIViewControllerRepresentable {
    public let coordinator: Representable.Coordinator
    public var transaction: Transaction { Transaction() }
    public var environment: EnvironmentValues
    init(coordinator: Representable.Coordinator, environment: EnvironmentValues) {
        self.coordinator = coordinator
        self.environment = environment
    }
}
