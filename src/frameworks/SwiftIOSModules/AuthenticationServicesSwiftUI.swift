// _AuthenticationServices_SwiftUI's SignInWithAppleButton, with the public shape of the iOS 16.5 SDK's
// interface. Darling has no Apple ID, so a tap cannot sign in: it reports that the request was not
// handled, as ASAuthorizationController does when no provider can answer one.
@_exported import AuthenticationServices
import Foundation
import SwiftUI

private struct ButtonStyleKey: EnvironmentKey {
    static let defaultValue = SignInWithAppleButton.Style.black
}
extension EnvironmentValues {
    fileprivate var signInWithAppleButtonStyle: SignInWithAppleButton.Style {
        get { self[ButtonStyleKey.self] }
        set { self[ButtonStyleKey.self] = newValue }
    }
}

@available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
public struct SignInWithAppleButton: View {
    public struct Label {
        fileprivate let title: String
        public static let signIn = Label(title: "Sign in with Apple")
        public static let `continue` = Label(title: "Continue with Apple")
        public static let signUp = Label(title: "Sign up with Apple")
    }
    public struct Style {
        fileprivate let foreground: Color
        fileprivate let background: Color
        public static let black = Style(foreground: .white, background: .black)
        public static let white = Style(foreground: .black, background: .white)
        public static let whiteOutline = Style(foreground: .black, background: .white)
    }

    private let label: Label
    private let onCompletion: (Result<ASAuthorization, any Error>) -> Void
    @Environment(\.signInWithAppleButtonStyle) private var style

    public init(_ label: Label = .signIn,
                onRequest: @escaping (ASAuthorizationAppleIDRequest) -> Void,
                onCompletion: @escaping (Result<ASAuthorization, any Error>) -> Void) {
        self.label = label
        self.onCompletion = onCompletion
    }

    public var body: some View {
        Button(action: {
            onCompletion(.failure(NSError(domain: "ASAuthorizationErrorDomain", code: 1003)))
        }, label: {
            Text(verbatim: label.title)
                .foregroundColor(style.foreground)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(style.background)
        })
    }
}

extension View {
    @available(iOS 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
    public func signInWithAppleButtonStyle(_ style: SignInWithAppleButton.Style) -> some View {
        environment(\.signInWithAppleButtonStyle, style)
    }
}
