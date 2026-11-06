// CoordinateSpaceProtocol, LongPressGesture and the DragGesture initializer that takes the protocol,
// from the iOS 18.0 SDK's interfaces. View.gesture does not attach gestures yet (see
// ABIViewModifiers.swift), so these values only have to exist.
import CoreFoundation

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public protocol CoordinateSpaceProtocol {
    var coordinateSpace: CoordinateSpace { get }
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public struct LocalCoordinateSpace: CoordinateSpaceProtocol {
    public init() {}
    public var coordinateSpace: CoordinateSpace { .local }
}
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension CoordinateSpaceProtocol where Self == LocalCoordinateSpace {
    public static var local: LocalCoordinateSpace { LocalCoordinateSpace() }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@available(tvOS, unavailable)
extension DragGesture {
    public init<T>(minimumDistance: CGFloat = 10, coordinateSpace: T = .local) where T: CoordinateSpaceProtocol {
        self.minimumDistance = minimumDistance
        self.coordinateSpace = coordinateSpace.coordinateSpace
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 14.0, *)
public struct LongPressGesture: Gesture {
    public var minimumDuration: Double
    public var maximumDistance: CGFloat
    public init(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10) {
        self.minimumDuration = minimumDuration
        self.maximumDistance = maximumDistance
    }
    public static func _makeGesture(gesture: _GraphValue<LongPressGesture>, inputs: _GestureInputs) -> _GestureOutputs<LongPressGesture.Value> {
        _abiUnimplemented("LongPressGesture._makeGesture")
    }
    public typealias Value = Bool
    public typealias Body = Never
}
