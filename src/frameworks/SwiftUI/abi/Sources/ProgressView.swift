// Resilient progress values with a textual presentation for the UIKit backend.
// Native animated indicators and custom progress styles require layout support.
public struct ProgressView<Label: View, CurrentValueLabel: View>: View {
    private let fraction: Double?
    private let label: Label
    private let currentValueLabel: CurrentValueLabel

    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1,
        @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {
        fraction = value.map { total > 0 ? min(max(Double($0 / total), 0), 1) : 0 }
        self.label = label()
        self.currentValueLabel = currentValueLabel()
    }
    public var body: some View {
        ProgressBody(fraction: fraction, label: label, currentValueLabel: currentValueLabel)
    }
}

private struct ProgressBody<Label: View, CurrentValueLabel: View>: View {
    let fraction: Double?
    let label: Label
    let currentValueLabel: CurrentValueLabel
    typealias Body = Never
    static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
        let value = view.value
        let label = Label._makeView(view: _GraphValue(value: value.label), inputs: inputs).text
        let current = CurrentValueLabel._makeView(view: _GraphValue(value: value.currentValueLabel), inputs: inputs).text
        let status = value.fraction.map { $0.isFinite ? "\(Int($0 * 100))%" : "0%" } ?? "Loading…"
        return _ViewOutputs(text: [label, status, current].filter { !$0.isEmpty }.joined(separator: "\n"))
    }
}

extension ProgressView where CurrentValueLabel == EmptyView {
    public init() where Label == EmptyView {
        self.init(value: Optional<Double>.none, label: { EmptyView() }, currentValueLabel: { EmptyView() })
    }
    public init(@ViewBuilder label: () -> Label) {
        self.init(value: Optional<Double>.none, label: label, currentValueLabel: { EmptyView() })
    }
    public init(_ titleKey: LocalizedStringKey) where Label == Text {
        self.init(label: { Text(titleKey) })
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S) where Label == Text {
        self.init(label: { Text(verbatim: String(title)) })
    }
}
extension ProgressView {
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1) where Label == EmptyView, CurrentValueLabel == EmptyView {
        self.init(value: value, total: total, label: { EmptyView() }, currentValueLabel: { EmptyView() })
    }
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1, @ViewBuilder label: () -> Label) where CurrentValueLabel == EmptyView {
        self.init(value: value, total: total, label: label, currentValueLabel: { EmptyView() })
    }
    public init<V: BinaryFloatingPoint>(_ titleKey: LocalizedStringKey, value: V?, total: V = 1) where Label == Text, CurrentValueLabel == EmptyView {
        self.init(value: value, total: total, label: { Text(titleKey) })
    }
    @_disfavoredOverload public init<S: StringProtocol, V: BinaryFloatingPoint>(_ title: S, value: V?, total: V = 1) where Label == Text, CurrentValueLabel == EmptyView {
        self.init(value: value, total: total, label: { Text(verbatim: String(title)) })
    }
}
