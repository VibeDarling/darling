// Storage adapted from OpenSwiftUI/View/Combine/SubscriptionView.swift (MIT).
import Combine

private var subscriptions: [AnyCancellable] = []

@frozen public struct SubscriptionView<PublisherType: Publisher, Content: View>: View
where PublisherType.Failure == Never {
    public var content: Content
    public var publisher: PublisherType
    public var action: (PublisherType.Output) -> Void
    public init(content: Content, publisher: PublisherType, action: @escaping (PublisherType.Output) -> Void) {
        self.content = content
        self.publisher = publisher
        self.action = action
    }
    public typealias Body = Never
    public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let objects = inputs.objects
        let action = view.value.action
        let create = {
            view.value.publisher.sink { value in
                EnvironmentScope.withObjects(objects) { action(value) }
            }
        }
        if let graph = inputs.graph { graph.subscription(at: inputs.path, create: create) }
        else { subscriptions.append(create()) }
        return Content._makeView(view: _GraphValue(value: view.value.content), inputs: inputs.child("subscriptionContent"))
    }
}
extension View {
    public func onReceive<P: Publisher>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> some View
    where P.Failure == Never {
        SubscriptionView(content: self, publisher: publisher, action: action)
    }
}
