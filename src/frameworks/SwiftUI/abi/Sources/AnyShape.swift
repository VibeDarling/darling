import CoreFoundation

// Keep both SDK-frozen fields: a vtable metatype and an Any value. The vtable
// supplies the concrete vector operations without guessing a payload's layout.
@usableFromInline class _AnyAnimatableDataVTable {
    class func equal(_ a: Any, _ b: Any) -> Bool { fatalError("abstract vector vtable") }
    class func add(_ a: Any, _ b: Any) -> Any { fatalError("abstract vector vtable") }
    class func subtract(_ a: Any, _ b: Any) -> Any { fatalError("abstract vector vtable") }
    class func scale(_ a: Any, by factor: Double) -> Any { fatalError("abstract vector vtable") }
    class func magnitude(_ a: Any) -> Double { fatalError("abstract vector vtable") }
}
private final class VectorVTable<V: VectorArithmetic>: _AnyAnimatableDataVTable {
    override class func equal(_ a: Any, _ b: Any) -> Bool { (a as! V) == (b as! V) }
    override class func add(_ a: Any, _ b: Any) -> Any { (a as! V) + (b as! V) }
    override class func subtract(_ a: Any, _ b: Any) -> Any { (a as! V) - (b as! V) }
    override class func scale(_ a: Any, by factor: Double) -> Any { var result = a as! V; result.scale(by: factor); return result }
    override class func magnitude(_ a: Any) -> Double { (a as! V).magnitudeSquared }
}
@frozen public struct _AnyAnimatableData: VectorArithmetic {
    @usableFromInline var vtable: _AnyAnimatableDataVTable.Type
    @usableFromInline var value: Any
    init<V: VectorArithmetic>(_ value: V) { self.value = value; vtable = VectorVTable<V>.self }
    private var isUnit: Bool { vtable == VectorVTable<EmptyAnimatableData>.self }
    func typed<V: VectorArithmetic>(as: V.Type) -> V { isUnit ? .zero : value as! V }
    public static var zero: Self { .init(EmptyAnimatableData()) }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.isUnit || rhs.isUnit { return lhs.magnitudeSquared == 0 && rhs.magnitudeSquared == 0 }
        return lhs.vtable == rhs.vtable && lhs.vtable.equal(lhs.value, rhs.value)
    }
    public static func += (lhs: inout Self, rhs: Self) {
        if rhs.isUnit { return }
        if lhs.isUnit { lhs = rhs; return }
        precondition(lhs.vtable == rhs.vtable, "incompatible erased animation vectors")
        lhs.value = lhs.vtable.add(lhs.value, rhs.value)
    }
    public static func -= (lhs: inout Self, rhs: Self) {
        if rhs.isUnit { return }
        if lhs.isUnit { lhs = rhs; lhs.scale(by: -1); return }
        precondition(lhs.vtable == rhs.vtable, "incompatible erased animation vectors")
        lhs.value = lhs.vtable.subtract(lhs.value, rhs.value)
    }
    @inlinable public static func + (lhs: Self, rhs: Self) -> Self { var result = lhs; result += rhs; return result }
    @inlinable public static func - (lhs: Self, rhs: Self) -> Self { var result = lhs; result -= rhs; return result }
    public mutating func scale(by rhs: Double) { value = vtable.scale(value, by: rhs) }
    public var magnitudeSquared: Double { vtable.magnitude(value) }
}
@usableFromInline class AnyShapeBox {
    func path(in rect: CGRect) -> Path { fatalError("abstract shape box") }
    func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { fatalError("abstract shape box") }
    var data: _AnyAnimatableData { get { fatalError("abstract shape box") } set { fatalError("abstract shape box") } }
    func copy() -> AnyShapeBox { fatalError("abstract shape box") }
}
private final class ConcreteShapeBox<S: Shape>: AnyShapeBox {
    var shape: S
    init(_ shape: S) { self.shape = shape }
    override func path(in rect: CGRect) -> Path { shape.path(in: rect) }
    override func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { shape.sizeThatFits(proposal) }
    override var data: _AnyAnimatableData {
        get { .init(shape.animatableData) }
        set { shape.animatableData = newValue.typed(as: S.AnimatableData.self) }
    }
    override func copy() -> AnyShapeBox { ConcreteShapeBox(shape) }
}
@frozen public struct AnyShape: Shape {
    @usableFromInline var storage: AnyShapeBox
    public init<S: Shape>(_ shape: S) { storage = ConcreteShapeBox(shape) }
    public func path(in rect: CGRect) -> Path { storage.path(in: rect) }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { storage.sizeThatFits(proposal) }
    public var animatableData: _AnyAnimatableData {
        get { storage.data }
        set { if !isKnownUniquelyReferenced(&storage) { storage = storage.copy() }; storage.data = newValue }
    }
}
