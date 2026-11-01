// EnvironmentValues members of the SDK interface that apps read, with the defaults of an iPhone in
// portrait at the default text size. Values a view writes are kept like any other environment key;
// Darling's renderer does not act on most of them yet.
import CoreFoundation
import UIKit

extension Image {
    public enum Scale: Hashable {
        case small
        case medium
        case large
    }
}

extension Text {
    public enum TruncationMode: Hashable {
        case head
        case tail
        case middle
    }
}

private struct DynamicTypeSizeKey: EnvironmentKey { static let defaultValue = DynamicTypeSize.large }
private struct ForegroundColorKey: EnvironmentKey { static let defaultValue: Color? = nil }
private struct HorizontalSizeClassKey: EnvironmentKey { static let defaultValue: UserInterfaceSizeClass? = .compact }
private struct VerticalSizeClassKey: EnvironmentKey { static let defaultValue: UserInterfaceSizeClass? = .regular }
private struct ImageScaleKey: EnvironmentKey { static let defaultValue = Image.Scale.medium }
private struct IsScrollEnabledKey: EnvironmentKey { static let defaultValue = true }
private struct IsSearchingKey: EnvironmentKey { static let defaultValue = false }
private struct LayoutDirectionKey: EnvironmentKey { static let defaultValue = LayoutDirection.leftToRight }
private struct LineSpacingKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
private struct LineHeightMultipleKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
private struct MinimumScaleFactorKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
private struct MultilineTextAlignmentKey: EnvironmentKey { static let defaultValue = TextAlignment.leading }
private struct RedactionReasonsKey: EnvironmentKey { static let defaultValue: RedactionReasons = [] }
private struct TextContentTypeKey: EnvironmentKey { static let defaultValue: String? = nil }
private struct TruncationModeKey: EnvironmentKey { static let defaultValue = Text.TruncationMode.tail }
private struct AllowsTighteningKey: EnvironmentKey { static let defaultValue = false }
private struct OpenURLKey: EnvironmentKey {
    static let defaultValue = OpenURLAction(handler: { _ in .systemAction })
}

extension EnvironmentValues {
    public var dynamicTypeSize: DynamicTypeSize {
        get { self[DynamicTypeSizeKey.self] }
        set { self[DynamicTypeSizeKey.self] = newValue }
    }
    @usableFromInline internal var foregroundColor: Color? {
        get { self[ForegroundColorKey.self] }
        set { self[ForegroundColorKey.self] = newValue }
    }
    public var horizontalSizeClass: UserInterfaceSizeClass? {
        get { self[HorizontalSizeClassKey.self] }
        set { self[HorizontalSizeClassKey.self] = newValue }
    }
    public var verticalSizeClass: UserInterfaceSizeClass? {
        get { self[VerticalSizeClassKey.self] }
        set { self[VerticalSizeClassKey.self] = newValue }
    }
    public var imageScale: Image.Scale {
        get { self[ImageScaleKey.self] }
        set { self[ImageScaleKey.self] = newValue }
    }
    public var isScrollEnabled: Bool {
        get { self[IsScrollEnabledKey.self] }
        set { self[IsScrollEnabledKey.self] = newValue }
    }
    public var isSearching: Bool { self[IsSearchingKey.self] }
    public var layoutDirection: LayoutDirection {
        get { self[LayoutDirectionKey.self] }
        set { self[LayoutDirectionKey.self] = newValue }
    }
    public var lineSpacing: CGFloat {
        get { self[LineSpacingKey.self] }
        set { self[LineSpacingKey.self] = newValue }
    }
    public var _lineHeightMultiple: CGFloat {
        get { self[LineHeightMultipleKey.self] }
        set { self[LineHeightMultipleKey.self] = newValue }
    }
    public var minimumScaleFactor: CGFloat {
        get { self[MinimumScaleFactorKey.self] }
        set { self[MinimumScaleFactorKey.self] = newValue }
    }
    public var multilineTextAlignment: TextAlignment {
        get { self[MultilineTextAlignmentKey.self] }
        set { self[MultilineTextAlignmentKey.self] = newValue }
    }
    public var redactionReasons: RedactionReasons {
        get { self[RedactionReasonsKey.self] }
        set { self[RedactionReasonsKey.self] = newValue }
    }
    @usableFromInline internal var textContentType: String? {
        get { self[TextContentTypeKey.self] }
        set { self[TextContentTypeKey.self] = newValue }
    }
    public var truncationMode: Text.TruncationMode {
        get { self[TruncationModeKey.self] }
        set { self[TruncationModeKey.self] = newValue }
    }
    public var allowsTightening: Bool {
        get { self[AllowsTighteningKey.self] }
        set { self[AllowsTighteningKey.self] = newValue }
    }
    /// Darling has no accessibility settings: motion is never reduced.
    public var accessibilityReduceMotion: Bool { false }
    public var openURL: OpenURLAction {
        get { self[OpenURLKey.self] }
        set { self[OpenURLKey.self] = newValue }
    }
    /// Inside a sheet or full-screen cover, dismissing ends that presentation (see Presentation.swift).
    public var presentationMode: Binding<PresentationMode> {
        .constant(PresentationMode(dismissAction: dismiss))
    }
}

public struct OpenURLAction {
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public struct Result {
        fileprivate enum Kind { case handled, discarded, systemAction(URL?) }
        fileprivate let kind: Kind
        public static let handled = Result(kind: .handled)
        public static let discarded = Result(kind: .discarded)
        public static let systemAction = Result(kind: .systemAction(nil))
        public static func systemAction(_ url: URL) -> OpenURLAction.Result { Result(kind: .systemAction(url)) }
    }
    private let handler: (URL) -> Result

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public init(handler: @escaping (URL) -> OpenURLAction.Result) { self.handler = handler }

    public func callAsFunction(_ url: URL) { callAsFunction(url) { _ in } }

    /// Runs the handler; a system action opens the URL with UIApplication, as SwiftUI does.
    public func callAsFunction(_ url: URL, completion: @escaping (_ accepted: Bool) -> Void) {
        switch handler(url).kind {
        case .handled: completion(true)
        case .discarded: completion(false)
        case .systemAction(let other):
            let target = other ?? url
            let application = UIApplication.shared
            completion(application.canOpenURL(target) && application.openURL(target))
        }
    }
}

public struct PresentationMode {
    let dismissAction: DismissAction
    public var isPresented: Bool { dismissAction.action != nil }
    public mutating func dismiss() { dismissAction() }
}
