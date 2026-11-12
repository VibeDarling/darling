// Label, its styles and Divider, with the iOS 16.5 SDK's declarations.
import Foundation
import UIKit

/// A title beside an icon, drawn by the label style in the environment (icon then title by default).
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct Label<Title, Icon> : View where Title : View, Icon : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  private var title: Title
  private var icon: Icon
  fileprivate init(title: Title, icon: Icon) { self.title = title; self.icon = icon }
  public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) { self.init(title: title(), icon: icon()) }
  @Environment(\._darlingLabelStyle) private var style
  @preconcurrency @MainActor public var body: some View {
    style.makeBody(LabelStyleConfiguration(title: .init(view: AnyView(title)), icon: .init(view: AnyView(icon))))
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Label where Title == Text, Icon == Image {
  public init(_ titleKey: LocalizedStringKey, image name: Swift.String) { self.init(title: Text(titleKey), icon: Image(name)) }
  public init(_ titleKey: LocalizedStringKey, systemImage name: Swift.String) { self.init(title: Text(titleKey), icon: Image(systemName: name)) }
  @_disfavoredOverload public init<S>(_ title: S, image name: Swift.String) where S : Swift.StringProtocol { self.init(title: Text(title), icon: Image(name)) }
  @_disfavoredOverload public init<S>(_ title: S, systemImage name: Swift.String) where S : Swift.StringProtocol { self.init(title: Text(title), icon: Image(systemName: name)) }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension Label where Title == LabelStyleConfiguration.Title, Icon == LabelStyleConfiguration.Icon {
  public init(_ configuration: LabelStyleConfiguration) { self.init(title: configuration.title, icon: configuration.icon) }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct LabelStyleConfiguration {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
  fileprivate init(title: Title, icon: Icon) { self.title = title; self.icon = icon }
  public struct Title {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
    fileprivate let view: AnyView
    fileprivate init(view: AnyView) { self.view = view }
    public typealias Body = Swift.Never
  }
  public struct Icon {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { _abiUnimplemented("a value of this type") }
    fileprivate let view: AnyView
    fileprivate init(view: AnyView) { self.view = view }
    public typealias Body = Swift.Never
  }
  public private(set) var title: LabelStyleConfiguration.Title
  public private(set) var icon: LabelStyleConfiguration.Icon
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LabelStyleConfiguration.Title : View {
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    AnyView._makeView(view: _GraphValue(value: view.value.view), inputs: inputs)
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension LabelStyleConfiguration.Icon : View {
  public static func _makeView(view: _GraphValue<Self>, inputs: _ViewInputs) -> _ViewOutputs {
    AnyView._makeView(view: _GraphValue(value: view.value.view), inputs: inputs)
  }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct DefaultLabelStyle : LabelStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0) }
  public func makeBody(configuration: DefaultLabelStyle.Configuration) -> some View {
    HStack(spacing: 8) { configuration.icon; configuration.title }
  }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct IconOnlyLabelStyle : LabelStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0) }
  public func makeBody(configuration: IconOnlyLabelStyle.Configuration) -> some View { configuration.icon }
}
@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct TitleOnlyLabelStyle : LabelStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0) }
  public func makeBody(configuration: TitleOnlyLabelStyle.Configuration) -> some View { configuration.title }
}
@available(iOS 14.5, macOS 11.3, tvOS 14.5, watchOS 7.4, *)
public struct TitleAndIconLabelStyle : LabelStyle {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0) }
  public func makeBody(configuration: TitleAndIconLabelStyle.Configuration) -> some View {
    HStack(spacing: 8) { configuration.icon; configuration.title }
  }
}

/// The label style in the environment, with its type erased.
struct _AnyLabelStyle {
  let makeBody: (LabelStyleConfiguration) -> AnyView
  init<S: LabelStyle>(_ style: S) { makeBody = { AnyView(style.makeBody(configuration: $0)) } }
}
private struct LabelStyleKey: EnvironmentKey {
  static var defaultValue: _AnyLabelStyle { _AnyLabelStyle(DefaultLabelStyle()) }
}
extension EnvironmentValues {
  var _darlingLabelStyle: _AnyLabelStyle {
    get { self[LabelStyleKey.self] }
    set { self[LabelStyleKey.self] = newValue }
  }
}
extension View {
  @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
  public func labelStyle<S: LabelStyle>(_ style: S) -> some View {
    environment(\._darlingLabelStyle, _AnyLabelStyle(style))
  }
}

/// A thin line across a vertical stack, or down a horizontal one.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct Divider : View {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public init() { self.init(_abiTag: 0) }
  public static func _makeView(view: _GraphValue<Divider>, inputs: _ViewInputs) -> _ViewOutputs {
    let line = Color(uiColor: .separator)
    if inputs.stackAxis == "horizontal" {
      let view = line.frame(width: 1)
      return type(of: view)._makeView(view: _GraphValue(value: view), inputs: inputs.child("divider"))
    }
    let view = line.frame(height: 1)
    return type(of: view)._makeView(view: _GraphValue(value: view), inputs: inputs.child("divider"))
  }
  public typealias Body = Swift.Never
}
