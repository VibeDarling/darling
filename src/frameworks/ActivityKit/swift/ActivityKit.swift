// ActivityKit for Darling, with the declarations of the iOS SDK's interface so apps that use Live
// Activities link and run. Darling has no Lock Screen or Dynamic Island: there are never any
// activities, and requesting one fails with ActivityAuthorizationError.unsupported, as on a device
// without Live Activities.
import Foundation

public protocol ActivityAttributes: Decodable, Encodable {
    associatedtype ContentState: Decodable, Encodable, Hashable
}

public struct ActivityContent<State> where State: Decodable, State: Encodable, State: Hashable {
    public let state: State
    public let staleDate: Date?
    public let relevanceScore: Double
    public init(state: State, staleDate: Date?, relevanceScore: Double = 0.0) {
        self.state = state
        self.staleDate = staleDate
        self.relevanceScore = relevanceScore
    }
}

extension ActivityContent: CustomStringConvertible {
    public var description: String { "ActivityContent(state: \(state))" }
}

public enum ActivityState: Equatable, Hashable, Codable {
    case active
    case ended
    case dismissed
    case stale
}

public struct PushType: Equatable {
    public static var token: PushType { PushType() }
}

public struct AlertConfiguration: Equatable {
    public var title: LocalizedStringResource
    public var body: LocalizedStringResource
    public var sound: AlertConfiguration.AlertSound
    public init(title: LocalizedStringResource, body: LocalizedStringResource, sound: AlertConfiguration.AlertSound) {
        self.title = title
        self.body = body
        self.sound = sound
    }
    public struct AlertSound: Equatable {
        private let name: String?
        public static var `default`: AlertConfiguration.AlertSound { AlertSound(name: nil) }
        public static func named(_ name: String) -> AlertConfiguration.AlertSound { AlertSound(name: name) }
    }
    public static func == (a: AlertConfiguration, b: AlertConfiguration) -> Bool { a.sound == b.sound }
}

public struct ActivityUIDismissalPolicy: Equatable {
    private let date: Date?
    private let immediately: Bool
    public static let `default` = ActivityUIDismissalPolicy(date: nil, immediately: false)
    public static let immediate = ActivityUIDismissalPolicy(date: nil, immediately: true)
    public static func after(_ date: Date) -> ActivityUIDismissalPolicy { ActivityUIDismissalPolicy(date: date, immediately: false) }
}

public enum ActivityAuthorizationError: CustomNSError, LocalizedError {
    case attributesTooLarge
    case unsupported
    case denied
    case globalMaximumExceeded
    case targetMaximumExceeded
    case unsupportedTarget
    case visibility
    case persistenceFailure
    case missingProcessIdentifier
    case unentitled
    case malformedActivityIdentifier
    case reconnectNotPermitted
    public static var errorDomain: String { "com.apple.ActivityKit.ActivityAuthorizationError" }
    public var errorCode: Int {
        switch self {
        case .attributesTooLarge: return 0
        case .unsupported: return 1
        case .denied: return 2
        case .globalMaximumExceeded: return 3
        case .targetMaximumExceeded: return 4
        case .unsupportedTarget: return 5
        case .visibility: return 6
        case .persistenceFailure: return 7
        case .missingProcessIdentifier: return 8
        case .unentitled: return 9
        case .malformedActivityIdentifier: return 10
        case .reconnectNotPermitted: return 11
        }
    }
    public var failureReason: String? { "Live Activities are not supported on this device." }
    public var recoverySuggestion: String? { nil }
}

public final class ActivityAuthorizationInfo {
    public init() {}
    public final var areActivitiesEnabled: Bool { false }
    public final var frequentPushesEnabled: Bool { false }
}

public class Activity<Attributes>: Identifiable where Attributes: ActivityAttributes {
    public typealias ContentState = Attributes.ContentState

    public final let id: String
    public final let attributes: Attributes
    private var currentContent: ActivityContent<ContentState>

    private init(attributes: Attributes, content: ActivityContent<ContentState>) {
        id = UUID().uuidString
        self.attributes = attributes
        currentContent = content
    }

    public static func request(attributes: Attributes, contentState: Activity<Attributes>.ContentState, pushType: PushType? = nil) throws -> Activity<Attributes> {
        throw ActivityAuthorizationError.unsupported
    }
    public static func request(attributes: Attributes, content: ActivityContent<Activity<Attributes>.ContentState>, pushType: PushType? = nil) throws -> Activity<Attributes> {
        throw ActivityAuthorizationError.unsupported
    }
    public static var activities: [Activity<Attributes>] { [] }

    public var activityState: ActivityState { .ended }
    public var contentState: Activity<Attributes>.ContentState { currentContent.state }
    public var content: ActivityContent<Activity<Attributes>.ContentState> { currentContent }
    public var pushToken: Data? { nil }

    public func update(using contentState: Activity<Attributes>.ContentState) async {
        currentContent = ActivityContent(state: contentState, staleDate: nil)
    }
    public func update(_ content: ActivityContent<Activity<Attributes>.ContentState>) async {
        currentContent = content
    }
    public func update(using contentState: Activity<Attributes>.ContentState, alertConfiguration: AlertConfiguration? = nil) async {
        currentContent = ActivityContent(state: contentState, staleDate: nil)
    }
    public func update(_ content: ActivityContent<Activity<Attributes>.ContentState>, alertConfiguration: AlertConfiguration? = nil) async {
        currentContent = content
    }
    public func end(using contentState: Activity<Attributes>.ContentState? = nil, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {}
    public func end(_ content: ActivityContent<Activity<Attributes>.ContentState>?, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {}
}
