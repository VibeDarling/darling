// The Swift overlay of UIKit (libswiftUIKit) for Darling: the declarations of the iOS SDK's UIKit
// overlay that apps link against, over Darling's Objective-C UIKit. Only the parts iOS apps have been
// seen to import are here; their names and types are the SDK's, so the mangled symbols match.
@_exported import UIKit
import Foundation
import ObjectiveC

// MARK: - IndexPath

extension IndexPath {
    public init(row: Int, section: Int) { self.init(indexes: [section, row]) }
    public init(item: Int, section: Int) { self.init(indexes: [section, item]) }
    public var section: Int {
        get { self[0] }
        set { self[0] = newValue }
    }
    public var row: Int {
        get { self[1] }
        set { self[1] = newValue }
    }
    public var item: Int {
        get { self[1] }
        set { self[1] = newValue }
    }
}

// MARK: - Geometry

extension UIEdgeInsets: Equatable {
    public static func == (lhs: UIEdgeInsets, rhs: UIEdgeInsets) -> Bool {
        lhs.top == rhs.top && lhs.left == rhs.left && lhs.bottom == rhs.bottom && lhs.right == rhs.right
    }
}

// MARK: - UIApplication

extension UIApplication {
    public static let openNotificationSettingsURLString: String = "app-settings:notifications"
}

// MARK: - Actions and menus

extension UIAction {
    @_disfavoredOverload
    public convenience init(title: String = "", image: UIImage? = nil, identifier: UIAction.Identifier? = nil, discoverabilityTitle: String? = nil,
                            attributes: UIMenuElement.Attributes = [], state: UIMenuElement.State = .off, handler: @escaping UIActionHandler) {
        // A convenience initializer cannot use the +actionWithTitle:... factory, and the SDK's headers
        // declare no initializer taking the handler: set it, like the identifier, through KVC.
        self.init()
        self.title = title
        self.image = image
        let block: @convention(block) (UIAction) -> Void = { handler($0) }
        setValue(block, forKey: "handler")
        setValue((identifier?.rawValue ?? UUID().uuidString) as NSString, forKey: "identifier")
        if responds(to: NSSelectorFromString("setDiscoverabilityTitle:")) { self.discoverabilityTitle = discoverabilityTitle }
        if responds(to: NSSelectorFromString("setAttributes:")) { self.attributes = attributes }
        if responds(to: NSSelectorFromString("setState:")) { self.state = state }
    }
}

extension UIMenu {
    // The iOS 16 initializer. The SDK's headers leave Swift only init(coder:),
    // which Darling's UIMenu treats as a plain init; the rest is set through
    // KVC, like UIAction's handler above.
    @available(iOS 16.0, *)
    public convenience init(title: String = "", subtitle: String? = nil, image: UIImage? = nil,
                            identifier: UIMenu.Identifier? = nil, options: UIMenu.Options = [],
                            preferredElementSize: UIMenu.ElementSize = .large, children: [UIMenuElement] = []) {
        self.init(coder: NSCoder())!
        setValue(title as NSString, forKey: "title")
        setValue(subtitle.map { $0 as NSString }, forKey: "subtitle")
        setValue(image, forKey: "image")
        setValue((identifier?.rawValue ?? UUID().uuidString) as NSString, forKey: "identifier")
        setValue(options.rawValue, forKey: "options")
        setValue(children as NSArray, forKey: "children")
    }
}

extension UIBarButtonItem {
    public convenience init(title: String? = nil, image: UIImage? = nil, primaryAction: UIAction? = nil, menu: UIMenu? = nil) {
        self.init()
        self.title = title ?? primaryAction?.title
        self.image = image ?? primaryAction?.image
        if let action = primaryAction, responds(to: NSSelectorFromString("setPrimaryAction:")) { self.primaryAction = action }
        if let menu = menu, responds(to: NSSelectorFromString("setMenu:")) { self.menu = menu }
    }
}

// MARK: - Pointer interactions (iPad); kept as values, never shown

public enum UIPointerShape {
    case path(_: UIBezierPath)
    case roundedRect(_: CGRect, radius: CGFloat = UIPointerShape.defaultCornerRadius)
    case verticalBeam(length: CGFloat)
    case horizontalBeam(length: CGFloat)
    public static let defaultCornerRadius: CGFloat = 8
}

public enum UIPointerEffect {
    public enum TintMode {
        case none, overlay, underlay
    }
    case automatic(_: UITargetedPreview)
    case highlight(_: UITargetedPreview)
    case lift(_: UITargetedPreview)
    case hover(_: UITargetedPreview, preferredTintMode: UIPointerEffect.TintMode = .overlay, prefersShadow: Bool = false, prefersScaledContent: Bool = true)
    public var preview: UITargetedPreview {
        switch self {
        case .automatic(let preview), .highlight(let preview), .lift(let preview), .hover(let preview, _, _, _): return preview
        }
    }
}

extension UIPointerStyle {
    public convenience init(effect: UIPointerEffect, shape: UIPointerShape? = nil) { self.init() }
}

private var pointerStyleProviderKey = 0
extension UIButton {
    public typealias PointerStyleProvider = (_ button: UIButton, _ proposedEffect: UIPointerEffect, _ proposedShape: UIPointerShape) -> UIPointerStyle?
    public var pointerStyleProvider: UIButton.PointerStyleProvider? {
        get { objc_getAssociatedObject(self, &pointerStyleProviderKey) as? UIButton.PointerStyleProvider }
        set { objc_setAssociatedObject(self, &pointerStyleProviderKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - Content configurations

public protocol UIConfigurationState {
    var traitCollection: UITraitCollection { get set }
    subscript(key: UIConfigurationStateCustomKey) -> AnyHashable? { get set }
}

public protocol UIContentConfiguration {
    func makeContentView() -> any UIView & UIContentView
    func updated(for state: any UIConfigurationState) -> Self
}

public protocol UIContentView: NSObjectProtocol {
    var configuration: any UIContentConfiguration { get set }
    func supports(_ configuration: any UIContentConfiguration) -> Bool
}

extension UIContentView {
    public func supports(_ configuration: any UIContentConfiguration) -> Bool { true }
}

private var contentConfigurationKey = 0
private var contentConfigurationViewKey = 0
private func setContentConfiguration(_ configuration: (any UIContentConfiguration)?, on owner: NSObject, in container: UIView) {
    let old = objc_getAssociatedObject(owner, &contentConfigurationKey) as? any UIContentConfiguration
    let oldView = objc_getAssociatedObject(owner, &contentConfigurationViewKey) as? UIView
    objc_setAssociatedObject(owner, &contentConfigurationKey, configuration.map { $0 as Any }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    // A reused cell keeps its content view when the new configuration is of the same kind, as on iOS.
    if let configuration = configuration, let old = old, type(of: old) == type(of: configuration),
       let contentView = oldView as? (UIView & UIContentView), contentView.supports(configuration) {
        contentView.configuration = configuration
        return
    }
    oldView?.removeFromSuperview()
    let sizingView = NSSelectorFromString("setUikitConfigurationView:")
    guard let configuration = configuration else {
        objc_setAssociatedObject(owner, &contentConfigurationViewKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if owner.responds(to: sizingView) { owner.perform(sizingView, with: nil) }
        return
    }
    let view = configuration.makeContentView()
    view.frame = container.bounds
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.addSubview(view)
    objc_setAssociatedObject(owner, &contentConfigurationViewKey, view, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    // Cells size themselves from this view (UITableView's automatic row heights).
    if owner.responds(to: sizingView) { owner.perform(sizingView, with: view) }
}

extension UICollectionViewCell {
    public var contentConfiguration: (any UIContentConfiguration)? {
        get { objc_getAssociatedObject(self, &contentConfigurationKey) as? any UIContentConfiguration }
        set(config) { setContentConfiguration(config, on: self, in: contentView) }
    }
}

extension UITableViewCell {
    public var contentConfiguration: (any UIContentConfiguration)? {
        get { objc_getAssociatedObject(self, &contentConfigurationKey) as? any UIContentConfiguration }
        set(config) { setContentConfiguration(config, on: self, in: contentView) }
    }
}

extension UITableViewHeaderFooterView {
    public var contentConfiguration: (any UIContentConfiguration)? {
        get { objc_getAssociatedObject(self, &contentConfigurationKey) as? any UIContentConfiguration }
        set(config) { setContentConfiguration(config, on: self, in: contentView) }
    }
}

public struct UIBackgroundConfiguration: Hashable {
    public var backgroundColor: UIColor?
    public var cornerRadius: CGFloat = 0
    public init() {}
    public static func clear() -> UIBackgroundConfiguration { UIBackgroundConfiguration() }
}

public struct UIConfigurationTextAttributesTransformer {
    public let transform: (AttributeContainer) -> AttributeContainer
    public init(_ transform: @escaping (AttributeContainer) -> AttributeContainer) { self.transform = transform }
    public func callAsFunction(_ input: AttributeContainer) -> AttributeContainer { transform(input) }
}

// MARK: - UIButton.Configuration

extension UIButton {
    public struct Configuration: Hashable {
        public enum Size { case mini, small, medium, large }
        public enum TitleAlignment { case automatic, leading, center, trailing }
        public enum CornerStyle { case fixed, dynamic, small, medium, large, capsule }
        public enum MacIdiomStyle { case automatic, bordered, borderless, borderlessTinted }

        fileprivate enum Style { case plain, tinted, gray, filled, borderless, bordered, borderedTinted, borderedProminent }
        fileprivate var style: Style = .plain
        public var title: String?
        public var subtitle: String?
        public var image: UIImage?
        public var imagePadding: CGFloat = 0
        public var imagePlacement: NSDirectionalRectEdge = .leading
        public var contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        public var cornerStyle: UIButton.Configuration.CornerStyle = .dynamic
        public var background = UIBackgroundConfiguration()
        public var baseForegroundColor: UIColor?
        public var baseBackgroundColor: UIColor?
        public var preferredSymbolConfigurationForImage: UIImage.SymbolConfiguration?
        public var titleTextAttributesTransformer: UIConfigurationTextAttributesTransformer?

        public static func plain() -> UIButton.Configuration { Configuration(style: .plain) }
        public static func tinted() -> UIButton.Configuration { Configuration(style: .tinted) }
        public static func gray() -> UIButton.Configuration { Configuration(style: .gray) }
        public static func filled() -> UIButton.Configuration {
            var configuration = Configuration(style: .filled)
            configuration.background.backgroundColor = .systemBlue
            configuration.baseForegroundColor = .white
            return configuration
        }
        public static func borderless() -> UIButton.Configuration { Configuration(style: .borderless) }
        public static func bordered() -> UIButton.Configuration { Configuration(style: .bordered) }
        public static func borderedTinted() -> UIButton.Configuration { Configuration(style: .borderedTinted) }
        public static func borderedProminent() -> UIButton.Configuration { filled() }

        public static func == (a: UIButton.Configuration, b: UIButton.Configuration) -> Bool {
            a.style == b.style && a.title == b.title && a.subtitle == b.subtitle && a.image == b.image && a.cornerStyle == b.cornerStyle
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(subtitle)
        }
    }

    public convenience init(configuration: UIButton.Configuration, primaryAction: UIAction? = nil) {
        self.init(type: .system)
        self.configuration = configuration
        if let action = primaryAction {
            if title(for: .normal) == nil, !action.title.isEmpty { setTitle(action.title, for: .normal) }
            addAction(action, for: .touchUpInside)
        }
    }

    public var configuration: UIButton.Configuration? {
        get { objc_getAssociatedObject(self, &buttonConfigurationKey) as? UIButton.Configuration }
        set {
            objc_setAssociatedObject(self, &buttonConfigurationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if let configuration = newValue { apply(configuration) }
        }
    }

    /// Shows a configuration with the classic UIButton properties Darling's UIKit draws.
    private func apply(_ configuration: UIButton.Configuration) {
        setTitle(configuration.title, for: .normal)
        setImage(configuration.image, for: .normal)
        if let color = configuration.baseForegroundColor { setTitleColor(color, for: .normal); tintColor = color }
        if let color = configuration.background.backgroundColor ?? configuration.baseBackgroundColor { backgroundColor = color }
        let insets = configuration.contentInsets
        contentEdgeInsets = UIEdgeInsets(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
        switch configuration.cornerStyle {
        case .capsule: layer.cornerRadius = bounds.height / 2
        case .small: layer.cornerRadius = 4
        case .medium, .dynamic: layer.cornerRadius = 6
        case .large: layer.cornerRadius = 10
        case .fixed: layer.cornerRadius = configuration.background.cornerRadius
        }
    }
}
private var buttonConfigurationKey = 0

// MARK: - AttributedString

extension AttributeScopes {
    public struct UIKitAttributes {
        @frozen public enum FontAttribute: CodableAttributedStringKey {
            public typealias Value = UIFont
            public static let name: String = "NSFont"
            public static func encode(_ value: UIFont, to encoder: any Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(value.fontName)
            }
            public static func decode(from decoder: any Decoder) throws -> UIFont {
                let container = try decoder.singleValueContainer()
                return UIFont(name: try container.decode(String.self), size: UIFont.systemFontSize) ?? .systemFont(ofSize: UIFont.systemFontSize)
            }
        }
    }
}
