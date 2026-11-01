// SDK line-limit overloads return opaque modifier values. The optional public
// environment property holds the maximum; minimum/reservation stay local.
private struct LineLimitKey: EnvironmentKey { static let defaultValue: Int? = nil }
private struct MinimumLinesKey: EnvironmentKey { static let defaultValue = 0 }
extension EnvironmentValues {
    public var lineLimit: Int? { get { self[LineLimitKey.self] } set { self[LineLimitKey.self] = newValue } }
    var minimumLines: Int { get { self[MinimumLinesKey.self] } set { self[MinimumLinesKey.self] = newValue } }
}
struct LineLimitModifier: ViewModifier {
    let minimum: Int
    let maximum: Int?
    typealias Body = Never
    static func _makeView(modifier: _GraphValue<Self>, inputs: _ViewInputs, body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs) -> _ViewOutputs {
        var inputs = inputs
        inputs.environment.minimumLines = modifier.value.minimum
        inputs.environment.lineLimit = modifier.value.maximum
        return body(_Graph(), inputs)
    }
}
extension View {
    @inlinable public func lineLimit(_ number: Int?) -> some View { environment(\.lineLimit, number) }
    public func lineLimit(_ limit: ClosedRange<Int>) -> some View {
        precondition(limit.lowerBound >= 0)
        return modifier(LineLimitModifier(minimum: limit.lowerBound, maximum: limit.upperBound))
    }
    public func lineLimit(_ limit: PartialRangeFrom<Int>) -> some View {
        precondition(limit.lowerBound >= 0)
        return modifier(LineLimitModifier(minimum: limit.lowerBound, maximum: nil))
    }
    public func lineLimit(_ limit: PartialRangeThrough<Int>) -> some View {
        precondition(limit.upperBound >= 0)
        return modifier(LineLimitModifier(minimum: 0, maximum: limit.upperBound))
    }
    public func lineLimit(_ limit: Int, reservesSpace: Bool) -> some View {
        precondition(limit >= 0)
        return modifier(LineLimitModifier(minimum: reservesSpace ? limit : 0, maximum: limit))
    }
}
