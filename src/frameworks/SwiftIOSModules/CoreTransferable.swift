// CoreTransferable's core protocols with the public shape of the iOS 16 SDK's
// interface, so apps' mangled names match. Only the Data, String and URL
// conformances (SwiftUI's interface requires the last two) and the
// DataRepresentation they use are here: that is what the corpus binds. An app
// that names another representation fails at load rather than misbehaving.
import Foundation
import UniformTypeIdentifiers

@available(iOS 16.0, *)
public protocol TransferRepresentation<Item>: Sendable {
    associatedtype Item: Transferable
    associatedtype Body: TransferRepresentation
    @TransferRepresentationBuilder<Self.Item> var body: Self.Body { get }
}

@available(iOS 16.0, *)
public protocol Transferable {
    associatedtype Representation: TransferRepresentation
    @TransferRepresentationBuilder<Self> static var transferRepresentation: Self.Representation { get }
}

@available(iOS 16.0, *)
@resultBuilder
public struct TransferRepresentationBuilder<Item> where Item: Transferable {
    @_alwaysEmitIntoClient
    public static func buildExpression<R>(_ content: R) -> R where Item == R.Item, R: TransferRepresentation {
        content
    }

    @_alwaysEmitIntoClient
    public static func buildBlock<Content>(_ content: Content) -> Content
    where Item == Content.Item, Content: TransferRepresentation {
        content
    }
}

// Representations that are leaves have no body.
@available(iOS 16.0, *)
extension TransferRepresentation where Body == Never {
    public var body: Never { fatalError("\(Self.self) has no body") }
}

@available(iOS 16.0, *)
extension Never: TransferRepresentation {
    public typealias Item = Never
    public typealias Body = Never
}

@available(iOS 16.0, *)
extension Never: Transferable {
    public static var transferRepresentation: Never { fatalError() }
}

@available(iOS 16.0, *)
public struct DataRepresentation<Item>: TransferRepresentation where Item: Transferable {
    let contentType: UTType
    let exporting: (@Sendable (Item) async throws -> Data)?
    let importing: (@Sendable (Data) async throws -> Item)?

    public init(contentType: UTType, exporting: @escaping @Sendable (Item) async throws -> Data,
                importing: @escaping @Sendable (Data) async throws -> Item) {
        self.contentType = contentType
        self.exporting = exporting
        self.importing = importing
    }

    public init(exportedContentType: UTType, exporting: @escaping @Sendable (Item) async throws -> Data) {
        self.contentType = exportedContentType
        self.exporting = exporting
        self.importing = nil
    }

    public init(importedContentType: UTType, importing: @escaping @Sendable (Data) async throws -> Item) {
        self.contentType = importedContentType
        self.exporting = nil
        self.importing = importing
    }

    public typealias Body = Never
}

@available(iOS 16.0, *)
extension DataRepresentation: @unchecked Sendable {}

@available(iOS 16.0, *)
extension Data: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .data, exporting: { $0 }, importing: { $0 })
    }
}

@available(iOS 16.0, *)
extension String: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .utf8PlainText, exporting: { Data($0.utf8) },
                           importing: { String(decoding: $0, as: UTF8.self) })
    }
}

struct NotAURL: Error {}

@available(iOS 16.0, *)
extension URL: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .url, exporting: { Data($0.absoluteString.utf8) },
                           importing: { data in
                               guard let url = URL(string: String(decoding: data, as: UTF8.self)) else {
                                   throw NotAURL()
                               }
                               return url
                           })
    }
}
