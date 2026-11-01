// StoreKit's Swift API (StoreKit 2), generated from the iOS 16.5 SDK's StoreKit.swiftinterface so
// that names, case order and frozen layouts match what apps were compiled against, then given the
// behaviour of a device without the App Store: no products, no transactions, empty update streams,
// and StoreKitError.notAvailableInStorefront wherever Apple's servers would be asked.
// Members of values that can only come from the App Store trap (_storeKitNoInstance); purchase
// options and the remaining members trap with _abiUnimplemented.
import Foundation
import _Concurrency
import UIKit

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AppTransaction : Swift.Sendable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public var jsonRepresentation: Foundation.Data {
    get { _abiUnimplemented("AppTransaction: public var jsonRepresentation: Foundation.Data {") }
  }
  public var appID: Swift.UInt64? { _storeKitNoInstance() }
  public var appVersion: Swift.String { _storeKitNoInstance() }
  public var appVersionID: Swift.UInt64? { _storeKitNoInstance() }
  public var bundleID: Swift.String { _storeKitNoInstance() }
  public var environment: AppStore.Environment { _storeKitNoInstance() }
  public var originalAppVersion: Swift.String { _storeKitNoInstance() }
  public var originalPurchaseDate: Foundation.Date { _storeKitNoInstance() }
  public var preorderDate: Foundation.Date? { _storeKitNoInstance() }
  public var deviceVerification: Foundation.Data { _storeKitNoInstance() }
  public var deviceVerificationNonce: Foundation.UUID { _storeKitNoInstance() }
  public var signedDate: Foundation.Date { _storeKitNoInstance() }
  public static var shared: VerificationResult<AppTransaction> {
    get async throws { throw StoreKitError.notAvailableInStorefront }
  }
  public static func refresh() async throws -> VerificationResult<AppTransaction> { throw StoreKitError.notAvailableInStorefront }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension AppTransaction : Swift.Equatable {
  public static func == (lhs: AppTransaction, rhs: AppTransaction) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension AppTransaction : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension AppTransaction : Swift.CustomDebugStringConvertible {
  public var debugDescription: Swift.String { _storeKitNoInstance() }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@frozen public enum VerificationResult<SignedType> {
  case unverified(SignedType, VerificationResult<SignedType>.VerificationError)
  case verified(SignedType)
  public var payloadValue: SignedType {
    get throws { _abiUnimplemented("throwing getter") }
  }
  public var unsafePayloadValue: SignedType {
    get { _abiUnimplemented("VerificationResult: public var unsafePayloadValue: SignedType {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerificationResult {
  public enum VerificationError : Swift.Error {
    case revokedCertificate
    case invalidCertificateChain
    case invalidDeviceVerification
    case invalidEncoding
    case invalidSignature
    case missingRequiredProperties
    public static func == (a: VerificationResult<SignedType>.VerificationError, b: VerificationResult<SignedType>.VerificationError) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerificationResult : Swift.Equatable where SignedType : Swift.Equatable {
  public static func == (a: VerificationResult<SignedType>, b: VerificationResult<SignedType>) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerificationResult : Swift.Hashable where SignedType : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerificationResult : Swift.CustomDebugStringConvertible where SignedType : Swift.CustomDebugStringConvertible {
  public var debugDescription: Swift.String {
    get { _abiUnimplemented("VerificationResult: public var debugDescription: Swift.String {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerificationResult : Swift.Sendable where SignedType : Swift.Sendable {
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension VerificationResult.VerificationError : Foundation.LocalizedError {
  public var errorDescription: Swift.String? {
    get { "\(self)" }
  }
  public var failureReason: Swift.String? {
    get { nil }
  }
  public var recoverySuggestion: Swift.String? {
    get { nil }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension VerificationResult where SignedType == AppTransaction {
  public var jwsRepresentation: Swift.String {
    get { _abiUnimplemented("VerificationResult: public var jwsRepresentation: Swift.String {") }
  }
  public var headerData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var headerData: Foundation.Data {") }
  }
  public var payloadData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var payloadData: Foundation.Data {") }
  }
  public var signatureData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var signatureData: Foundation.Data {") }
  }
  public var signedData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var signedData: Foundation.Data {") }
  }
  public var signedDate: Foundation.Date {
    get { _abiUnimplemented("VerificationResult: public var signedDate: Foundation.Date {") }
  }
  public var deviceVerification: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var deviceVerification: Foundation.Data {") }
  }
  public var deviceVerificationNonce: Foundation.UUID {
    get { _abiUnimplemented("VerificationResult: public var deviceVerificationNonce: Foundation.UUID {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerificationResult where SignedType == Transaction {
  public var jwsRepresentation: Swift.String {
    get { _abiUnimplemented("VerificationResult: public var jwsRepresentation: Swift.String {") }
  }
  public var headerData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var headerData: Foundation.Data {") }
  }
  public var payloadData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var payloadData: Foundation.Data {") }
  }
  public var signatureData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var signatureData: Foundation.Data {") }
  }
  public var signedData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var signedData: Foundation.Data {") }
  }
  public var signedDate: Foundation.Date {
    get { _abiUnimplemented("VerificationResult: public var signedDate: Foundation.Date {") }
  }
  public var deviceVerification: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var deviceVerification: Foundation.Data {") }
  }
  public var deviceVerificationNonce: Foundation.UUID {
    get { _abiUnimplemented("VerificationResult: public var deviceVerificationNonce: Foundation.UUID {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerificationResult where SignedType == Product.SubscriptionInfo.RenewalInfo {
  public var jwsRepresentation: Swift.String {
    get { _abiUnimplemented("VerificationResult: public var jwsRepresentation: Swift.String {") }
  }
  public var headerData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var headerData: Foundation.Data {") }
  }
  public var payloadData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var payloadData: Foundation.Data {") }
  }
  public var signatureData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var signatureData: Foundation.Data {") }
  }
  public var signedData: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var signedData: Foundation.Data {") }
  }
  public var signedDate: Foundation.Date {
    get { _abiUnimplemented("VerificationResult: public var signedDate: Foundation.Date {") }
  }
  public var deviceVerification: Foundation.Data {
    get { _abiUnimplemented("VerificationResult: public var deviceVerification: Foundation.Data {") }
  }
  public var deviceVerificationNonce: Foundation.UUID {
    get { _abiUnimplemented("VerificationResult: public var deviceVerificationNonce: Foundation.UUID {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerificationResult.VerificationError : Swift.Equatable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension VerificationResult.VerificationError : Swift.Hashable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct Transaction : Swift.Identifiable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public struct RevocationReason : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable {
    public let rawValue: Swift.Int
    public init(rawValue: Swift.Int) { self.rawValue = rawValue }
    public static let developerIssue: Transaction.RevocationReason = Transaction.RevocationReason(rawValue: 1)
    public static let other: Transaction.RevocationReason = Transaction.RevocationReason(rawValue: 0)
    public typealias RawValue = Swift.Int
  }
  public struct OfferType : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable {
    public let rawValue: Swift.Int
    public init(rawValue: Swift.Int) { self.rawValue = rawValue }
    public static let introductory: Transaction.OfferType = Transaction.OfferType(rawValue: 1)
    public static let promotional: Transaction.OfferType = Transaction.OfferType(rawValue: 2)
    public static let code: Transaction.OfferType = Transaction.OfferType(rawValue: 3)
    public typealias RawValue = Swift.Int
  }
  public struct OwnershipType : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable {
    public let rawValue: Swift.String
    public init(rawValue: Swift.String) { self.rawValue = rawValue }
    public static let purchased: Transaction.OwnershipType = Transaction.OwnershipType(rawValue: "PURCHASED")
    public static let familyShared: Transaction.OwnershipType = Transaction.OwnershipType(rawValue: "FAMILY_SHARED")
    public typealias RawValue = Swift.String
  }
  public var jsonRepresentation: Foundation.Data {
    get { _abiUnimplemented("Transaction: public var jsonRepresentation: Foundation.Data {") }
  }
  public var id: Swift.UInt64 { _storeKitNoInstance() }
  public var originalID: Swift.UInt64 { _storeKitNoInstance() }
  public var webOrderLineItemID: Swift.String? { _storeKitNoInstance() }
  public var productID: Swift.String { _storeKitNoInstance() }
  public var subscriptionGroupID: Swift.String? { _storeKitNoInstance() }
  public var appBundleID: Swift.String { _storeKitNoInstance() }
  public var purchaseDate: Foundation.Date { _storeKitNoInstance() }
  public var originalPurchaseDate: Foundation.Date { _storeKitNoInstance() }
  public var expirationDate: Foundation.Date? { _storeKitNoInstance() }
  public var purchasedQuantity: Swift.Int { _storeKitNoInstance() }
  public var isUpgraded: Swift.Bool { _storeKitNoInstance() }
  public var offerType: Transaction.OfferType? { _storeKitNoInstance() }
  public var offerID: Swift.String? { _storeKitNoInstance() }
  public var revocationDate: Foundation.Date? { _storeKitNoInstance() }
  public var revocationReason: Transaction.RevocationReason? { _storeKitNoInstance() }
  public var productType: Product.ProductType { _storeKitNoInstance() }
  public var appAccountToken: Foundation.UUID? { _storeKitNoInstance() }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public var environment: AppStore.Environment { _storeKitNoInstance() }
  @available(iOS, introduced: 15.0, deprecated: 16.0, message: "Use the environment property instead")
  @available(macOS, introduced: 12.0, deprecated: 13.0, message: "Use the environment property instead")
  @available(tvOS, introduced: 15.0, deprecated: 16.0, message: "Use the environment property instead")
  @available(watchOS, introduced: 8.0, deprecated: 9.0, message: "Use the environment property instead")
  @available(macCatalyst, introduced: 15.0, deprecated: 16.0, message: "Use the environment property instead")
  public var environmentStringRepresentation: Swift.String { _storeKitNoInstance() }
  public var deviceVerification: Foundation.Data { _storeKitNoInstance() }
  public var deviceVerificationNonce: Foundation.UUID { _storeKitNoInstance() }
  public var ownershipType: Transaction.OwnershipType { _storeKitNoInstance() }
  public var signedDate: Foundation.Date { _storeKitNoInstance() }
  public func finish() async { _abiUnimplemented("Transaction: public func finish() async") }
  public typealias ID = Swift.UInt64
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction : Swift.Equatable {
  public static func == (lhs: Transaction, rhs: Transaction) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction : Swift.CustomDebugStringConvertible {
  public var debugDescription: Swift.String { _storeKitNoInstance() }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction {
  public struct Transactions : _Concurrency.AsyncSequence {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Element = VerificationResult<Transaction>
    public struct AsyncIterator : _Concurrency.AsyncIteratorProtocol {
      @usableFromInline internal var _abiTag: Int = 0
      @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
      public mutating func next() async -> VerificationResult<Transaction>? { nil }
      public typealias Element = VerificationResult<Transaction>
    }
    public func makeAsyncIterator() -> Transaction.Transactions.AsyncIterator { AsyncIterator(_abiTag: 0) }
  }
  public static var all: Transaction.Transactions {
    get { Transaction.Transactions(_abiTag: 0) }
  }
  public static var currentEntitlements: Transaction.Transactions {
    get { Transaction.Transactions(_abiTag: 0) }
  }
  public static func currentEntitlement(for productID: Swift.String) async -> VerificationResult<Transaction>? { nil }
  public static func latest(for productID: Swift.String) async -> VerificationResult<Transaction>? { nil }
  public static var unfinished: Transaction.Transactions {
    get { Transaction.Transactions(_abiTag: 0) }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction {
  public static var updates: Transaction.Transactions {
    get { Transaction.Transactions(_abiTag: 0) }
  }
}
@available(iOS 15.0, macCatalyst 15.0, macOS 12.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension Transaction {
  public enum RefundRequestError : Swift.Error {
    case duplicateRequest
    case failed
    public static func == (a: Transaction.RefundRequestError, b: Transaction.RefundRequestError) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
  public enum RefundRequestStatus {
    case success
    case userCancelled
    public static func == (a: Transaction.RefundRequestStatus, b: Transaction.RefundRequestStatus) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
  @available(iOS 15.0, macCatalyst 15.0, *)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  @inlinable public func beginRefundRequest(in scene: UIKit.UIWindowScene) async throws -> Transaction.RefundRequestStatus {
        return try await Transaction.beginRefundRequest(for: self.id, in: scene)
    }
  @available(iOS 15.0, macCatalyst 15.0, *)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  @_Concurrency.MainActor public static func beginRefundRequest(for transactionID: Swift.UInt64, in scene: UIKit.UIWindowScene) async throws -> Transaction.RefundRequestStatus { throw StoreKitError.notAvailableInStorefront }
}
@available(iOS 15.0, macCatalyst 15.0, macOS 12.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension Transaction.RefundRequestError : Swift.Sendable {
}
@available(iOS 15.0, macCatalyst 15.0, macOS 12.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension Transaction.RefundRequestStatus : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction.RevocationReason : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction.OfferType : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction.OwnershipType : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Transaction.Transactions : Swift.Sendable {
}
@available(iOS 15.4, macOS 12.3, *)
extension Transaction.RefundRequestError : Foundation.LocalizedError {
  public var errorDescription: Swift.String? {
    get { "\(self)" }
  }
  public var failureReason: Swift.String? {
    get { nil }
  }
  public var recoverySuggestion: Swift.String? {
    get { nil }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Transaction.OfferType {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Transaction: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Transaction.RevocationReason {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Transaction: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Transaction.OwnershipType {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Transaction: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.0, macCatalyst 15.0, macOS 12.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension Transaction.RefundRequestError : Swift.Equatable {}
@available(iOS 15.0, macCatalyst 15.0, macOS 12.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension Transaction.RefundRequestError : Swift.Hashable {}
@available(iOS 15.0, macCatalyst 15.0, macOS 12.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension Transaction.RefundRequestStatus : Swift.Equatable {}
@available(iOS 15.0, macCatalyst 15.0, macOS 12.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension Transaction.RefundRequestStatus : Swift.Hashable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct Storefront : Swift.Identifiable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public var countryCode: Swift.String { _storeKitNoInstance() }
  public var id: Swift.String { _storeKitNoInstance() }
  public static var current: Storefront? {
    get async { nil }
  }
  public typealias ID = Swift.String
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Storefront {
  public struct Storefronts : _Concurrency.AsyncSequence {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Element = Storefront
    public struct AsyncIterator : _Concurrency.AsyncIteratorProtocol {
      @usableFromInline internal var _abiTag: Int = 0
      @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
      public mutating func next() async -> Storefront? { nil }
      public typealias Element = Storefront
    }
    public func makeAsyncIterator() -> Storefront.Storefronts.AsyncIterator { AsyncIterator(_abiTag: 0) }
  }
  public static var updates: Storefront.Storefronts {
    get { Storefront.Storefronts(_abiTag: 0) }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Storefront : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Storefront.Storefronts : Swift.Sendable {
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct Product : Swift.Identifiable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public struct ProductType : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable {
    public let rawValue: Swift.String
    public init(rawValue: Swift.String) { self.rawValue = rawValue }
    public static let consumable: Product.ProductType = Product.ProductType(rawValue: "Consumable")
    public static let nonConsumable: Product.ProductType = Product.ProductType(rawValue: "Non-Consumable")
    public static let nonRenewable: Product.ProductType = Product.ProductType(rawValue: "Non-Renewable")
    public static let autoRenewable: Product.ProductType = Product.ProductType(rawValue: "Auto-Renewable")
    public typealias RawValue = Swift.String
  }
  public var jsonRepresentation: Foundation.Data {
    get { _abiUnimplemented("Product: public var jsonRepresentation: Foundation.Data {") }
  }
  public var id: Swift.String { _storeKitNoInstance() }
  public var type: Product.ProductType { _storeKitNoInstance() }
  public var displayName: Swift.String { _storeKitNoInstance() }
  public var description: Swift.String { _storeKitNoInstance() }
  public var price: Foundation.Decimal { _storeKitNoInstance() }
  public var displayPrice: Swift.String { _storeKitNoInstance() }
  public var isFamilyShareable: Swift.Bool { _storeKitNoInstance() }
  public var subscription: Product.SubscriptionInfo? { _storeKitNoInstance() }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public typealias ID = Swift.String
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product {
  public struct SubscriptionPeriod : Swift.Equatable, Swift.Hashable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public enum Unit : Swift.Equatable, Swift.Hashable {
      case day
      case week
      case month
      case year
      public static func == (a: Product.SubscriptionPeriod.Unit, b: Product.SubscriptionPeriod.Unit) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
      public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
      public var hashValue: Swift.Int {
        get { var h = Hasher(); hash(into: &h); return h.finalize() }
      }
    }
    public var unit: Product.SubscriptionPeriod.Unit { _storeKitNoInstance() }
    public var value: Swift.Int { _storeKitNoInstance() }
    @available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
    @usableFromInline
    internal init(from8601String string: Swift.String) throws { _abiUnimplemented("Product: internal init(from8601String string: Swift.String) throws") }
    @available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
    @usableFromInline
    internal init(unit: Product.SubscriptionPeriod.Unit, value: Swift.Int) { _abiUnimplemented("Product: internal init(unit: Product.SubscriptionPeriod.Unit, value: Swift.Int)") }
    public static func == (a: Product.SubscriptionPeriod, b: Product.SubscriptionPeriod) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionPeriod : Swift.CustomDebugStringConvertible {
  public var debugDescription: Swift.String {
    get { _abiUnimplemented("Product: public var debugDescription: Swift.String {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionPeriod.Unit : Swift.CustomDebugStringConvertible {
  public var debugDescription: Swift.String {
    get { _abiUnimplemented("Product: public var debugDescription: Swift.String {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionPeriod : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionPeriod.Unit : Swift.Sendable {
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Product.SubscriptionPeriod.Unit {
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  @usableFromInline
  internal var dynamicCalendarComponent: Foundation.Calendar.Component {
    get { _abiUnimplemented("Product: internal var dynamicCalendarComponent: Foundation.Calendar.Component {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionPeriod.Unit {
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, macCatalyst 15.0, *)
  @usableFromInline
  internal var calendarComponent: Foundation.Calendar.Component {
    get {
        // if we're on sydro+ call into the usable from inline method to check
        // for potential new cases
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            return dynamicCalendarComponent
        }
        // otherwise switch over the cases in starsky
        else {
            // this warning is a compiler bug, if we add @unknown default it will
            // give us another warning saying the default will never execute :)
            switch self {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            case .year: return .year
            }
        }
    }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionPeriod {
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, macCatalyst 15.0, *)
  public func dateRange(referenceDate: Foundation.Date = .now) -> Swift.Range<Foundation.Date> {
        let upperBound: Date! = Calendar(identifier: .gregorian).date(
            byAdding: unit.calendarComponent,
            value: value,
            to: referenceDate
        )
        return referenceDate..<upperBound
    }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, macCatalyst 15.0, *)
  public func formatted<S>(_ format: S, referenceDate: Foundation.Date = .now) -> S.FormatOutput where S : Foundation.FormatStyle, S.FormatInput == Swift.Range<Foundation.Date> {
        format.format(dateRange(referenceDate: referenceDate))
    }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Product.SubscriptionPeriod {
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public func formatted<S>(_ format: S, referenceDate: Foundation.Date = .now) -> S.FormatOutput where S : Foundation.FormatStyle, S.FormatInput == Swift.Duration { _abiUnimplemented("Product: public func formatted<S>(_ format: S, referenceDate: Foundation.Date = .now) -> S.FormatOutput where S : Foundation.Form") }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Product.SubscriptionPeriod.Unit {
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public struct FormatStyle : Foundation.FormatStyle {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public func format(_ value: Product.SubscriptionPeriod.Unit) -> Swift.String { _abiUnimplemented("Product: public func format(_ value: Product.SubscriptionPeriod.Unit) -> Swift.String") }
    public func locale(_ locale: Foundation.Locale) -> Product.SubscriptionPeriod.Unit.FormatStyle { _abiUnimplemented("Product: public func locale(_ locale: Foundation.Locale) -> Product.SubscriptionPeriod.Unit.FormatStyle") }
    public func encode(to encoder: any Swift.Encoder) throws { _abiUnimplemented("Product: public func encode(to encoder: any Swift.Encoder) throws") }
    public init(from decoder: any Swift.Decoder) throws { _abiUnimplemented("Product: public init(from decoder: any Swift.Decoder) throws") }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public static func == (a: Product.SubscriptionPeriod.Unit.FormatStyle, b: Product.SubscriptionPeriod.Unit.FormatStyle) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public typealias FormatInput = Product.SubscriptionPeriod.Unit
    public typealias FormatOutput = Swift.String
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
  @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
  public func formatted<S>(_ format: S) -> S.FormatOutput where S : Foundation.FormatStyle, S.FormatInput == Product.SubscriptionPeriod.Unit { _abiUnimplemented("Product: public func formatted<S>(_ format: S) -> S.FormatOutput where S : Foundation.FormatStyle, S.FormatInput == Product.Subsc") }
}
extension Product {
  @available(iOS 16.4, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public struct PromotionInfo : Swift.Equatable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public enum Visibility : Swift.Int, Swift.Equatable, Swift.Hashable {
      case appStoreConnectDefault
      case visible
      case hidden
      public init?(rawValue: Swift.Int) { return nil }
      public typealias RawValue = Swift.Int
      public var rawValue: Swift.Int {
        get { _abiUnimplemented("Product: public var rawValue: Swift.Int {") }
      }
    }
    public var productID: Product.ID { _storeKitNoInstance() }
    public var visibility: Product.PromotionInfo.Visibility {
      get { _storeKitNoInstance() }
      set { _storeKitNoInstance() }
    }
    public func update() async throws { _abiUnimplemented("Product: public func update() async throws") }
    public static var currentOrder: [Product.PromotionInfo] {
      get async throws { [] }
    }
    public static func updateProductOrder(byID order: some Collection<Product.ID>) async throws { throw StoreKitError.notAvailableInStorefront }
    public static func updateProductVisibility(_ visibility: Product.PromotionInfo.Visibility, for productID: Product.ID) async throws { throw StoreKitError.notAvailableInStorefront }
    public static func updateAll(_ promotions: some Collection<PromotionInfo>) async throws { throw StoreKitError.notAvailableInStorefront }
    public static func == (a: Product.PromotionInfo, b: Product.PromotionInfo) -> Swift.Bool { _storeKitNoInstance() }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product {
  public struct SubscriptionInfo : Swift.Equatable, Swift.Hashable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public var introductoryOffer: Product.SubscriptionOffer? { _storeKitNoInstance() }
    public var promotionalOffers: [Product.SubscriptionOffer] { _storeKitNoInstance() }
    public var subscriptionGroupID: Swift.String { _storeKitNoInstance() }
    public var subscriptionPeriod: Product.SubscriptionPeriod { _storeKitNoInstance() }
    @available(iOS 16.4, macOS 13.3, tvOS 16.4, watchOS 9.4, *)
    @inlinable public var isEligibleForIntroOffer: Swift.Bool {
      get async {
                await Self.isEligibleForIntroOffer(for: subscriptionGroupID)
            }
    }
    public static func isEligibleForIntroOffer(for groupID: Swift.String) async -> Swift.Bool { false }
    public static func == (a: Product.SubscriptionInfo, b: Product.SubscriptionInfo) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product {
  public struct PurchaseOption : Swift.Equatable, Swift.Hashable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public static func appAccountToken(_ token: Foundation.UUID) -> Product.PurchaseOption { _abiUnimplemented("Product: public static func appAccountToken(_ token: Foundation.UUID) -> Product.PurchaseOption") }
    public static func custom(key: Swift.String, value: Swift.String) -> Product.PurchaseOption { _abiUnimplemented("Product: public static func custom(key: Swift.String, value: Swift.String) -> Product.PurchaseOption") }
    public static func custom(key: Swift.String, value: Swift.Double) -> Product.PurchaseOption { _abiUnimplemented("Product: public static func custom(key: Swift.String, value: Swift.Double) -> Product.PurchaseOption") }
    public static func custom(key: Swift.String, value: Swift.Bool) -> Product.PurchaseOption { _abiUnimplemented("Product: public static func custom(key: Swift.String, value: Swift.Bool) -> Product.PurchaseOption") }
    public static func custom(key: Swift.String, value: Foundation.Data) -> Product.PurchaseOption { _abiUnimplemented("Product: public static func custom(key: Swift.String, value: Foundation.Data) -> Product.PurchaseOption") }
    public static func promotionalOffer(offerID: Swift.String, keyID: Swift.String, nonce: Foundation.UUID, signature: Foundation.Data, timestamp: Swift.Int) -> Product.PurchaseOption { _abiUnimplemented("Product: public static func promotionalOffer(offerID: Swift.String, keyID: Swift.String, nonce: Foundation.UUID, signature: Found") }
    public static func quantity(_ quantity: Swift.Int) -> Product.PurchaseOption { _abiUnimplemented("Product: public static func quantity(_ quantity: Swift.Int) -> Product.PurchaseOption") }
    public static func simulatesAskToBuyInSandbox(_ simulateAskToBuy: Swift.Bool) -> Product.PurchaseOption { _abiUnimplemented("Product: public static func simulatesAskToBuyInSandbox(_ simulateAskToBuy: Swift.Bool) -> Product.PurchaseOption") }
    @preconcurrency public static func onStorefrontChange(shouldContinuePurchase: @escaping @Sendable (Storefront) -> Swift.Bool) -> Product.PurchaseOption { _abiUnimplemented("Product: @preconcurrency public static func onStorefrontChange(shouldContinuePurchase: @escaping @Sendable (Storefront) -> Swift.") }
    public static func == (a: Product.PurchaseOption, b: Product.PurchaseOption) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.PurchaseOption : Swift.CustomDebugStringConvertible {
  public var debugDescription: Swift.String {
    get { _abiUnimplemented("Product: public var debugDescription: Swift.String {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.PurchaseOption : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product : Swift.Equatable {
  public static func == (lhs: Product, rhs: Product) -> Swift.Bool { _storeKitNoInstance() }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { _storeKitNoInstance() }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product : Swift.CustomDebugStringConvertible {
  public var debugDescription: Swift.String { _storeKitNoInstance() }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product {
  public enum PurchaseResult {
    case success(VerificationResult<Transaction>)
    case userCancelled
    case pending
  }
  public enum PurchaseError : Swift.Error {
    case invalidQuantity
    case productUnavailable
    case purchaseNotAllowed
    case ineligibleForOffer
    case invalidOfferIdentifier
    case invalidOfferPrice
    case invalidOfferSignature
    case missingOfferParameters
    public static func == (a: Product.PurchaseError, b: Product.PurchaseError) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
  public func purchase(options: Swift.Set<Product.PurchaseOption> = []) async throws -> Product.PurchaseResult { _abiUnimplemented("Product: public func purchase(options: Swift.Set<Product.PurchaseOption> = []) async throws -> Product.PurchaseResult") }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product {
  public static func products<Identifiers>(for identifiers: Identifiers) async throws -> [Product] where Identifiers : Swift.Collection, Identifiers.Element == Swift.String { [] }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product {
  @inlinable public var latestTransaction: VerificationResult<Transaction>? {
    get async {
            await Transaction.latest(for: id)
        }
  }
  @inlinable public var currentEntitlement: VerificationResult<Transaction>? {
    get async {
            await Transaction.currentEntitlement(for: id)
        }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.ProductType : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.PurchaseResult : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product {
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, macCatalyst 15.0, *)
  @usableFromInline
  internal var priceLocaleInternal: Foundation.Locale { _storeKitNoInstance() }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, macCatalyst 15.0, *)
  public var priceFormatStyle: Foundation.Decimal.FormatStyle.Currency {
    get {
        let locale = priceLocaleInternal
        return Decimal.FormatStyle.Currency(
            // We enforce this to be nonnull Sydro+, but we should handle without
            // crashing for back deployed OS
            code: locale.currencyCode ?? "",
            locale: locale
        )
    }
  }
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, macCatalyst 15.0, *)
  public var subscriptionPeriodFormatStyle: Foundation.Date.ComponentsFormatStyle {
    get {
        let locale = priceLocaleInternal
        return Date.ComponentsFormatStyle(
            // this default is arbitrary, callers can modify this as they'd like
            style: .spellOut,
            locale: locale,
            calendar: {
                var calendar = Calendar(identifier: .gregorian)
                calendar.locale = locale
                return calendar
            }()
        )
    }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension Product {
  public var subscriptionPeriodUnitFormatStyle: Product.SubscriptionPeriod.Unit.FormatStyle {
    get { _abiUnimplemented("Product: public var subscriptionPeriodUnitFormatStyle: Product.SubscriptionPeriod.Unit.Fo") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo {
  public struct RenewalState : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable {
    public let rawValue: Swift.Int
    public init(rawValue: Swift.Int) { self.rawValue = rawValue }
    public static let subscribed: Product.SubscriptionInfo.RenewalState = Product.SubscriptionInfo.RenewalState(rawValue: 1)
    public static let expired: Product.SubscriptionInfo.RenewalState = Product.SubscriptionInfo.RenewalState(rawValue: 2)
    public static let inBillingRetryPeriod: Product.SubscriptionInfo.RenewalState = Product.SubscriptionInfo.RenewalState(rawValue: 3)
    public static let inGracePeriod: Product.SubscriptionInfo.RenewalState = Product.SubscriptionInfo.RenewalState(rawValue: 4)
    public static let revoked: Product.SubscriptionInfo.RenewalState = Product.SubscriptionInfo.RenewalState(rawValue: 5)
    public typealias RawValue = Swift.Int
  }
  public struct RenewalInfo {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public struct ExpirationReason : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable {
      public let rawValue: Swift.Int
      public init(rawValue: Swift.Int) { self.rawValue = rawValue }
      public static let autoRenewDisabled: Product.SubscriptionInfo.RenewalInfo.ExpirationReason = Product.SubscriptionInfo.RenewalInfo.ExpirationReason(rawValue: 1)
      public static let billingError: Product.SubscriptionInfo.RenewalInfo.ExpirationReason = Product.SubscriptionInfo.RenewalInfo.ExpirationReason(rawValue: 2)
      public static let didNotConsentToPriceIncrease: Product.SubscriptionInfo.RenewalInfo.ExpirationReason = Product.SubscriptionInfo.RenewalInfo.ExpirationReason(rawValue: 3)
      public static let productUnavailable: Product.SubscriptionInfo.RenewalInfo.ExpirationReason = Product.SubscriptionInfo.RenewalInfo.ExpirationReason(rawValue: 4)
      public static let unknown: Product.SubscriptionInfo.RenewalInfo.ExpirationReason = Product.SubscriptionInfo.RenewalInfo.ExpirationReason(rawValue: 5)
      public typealias RawValue = Swift.Int
    }
    @frozen public enum PriceIncreaseStatus : Swift.Equatable, Swift.Hashable {
      case noIncreasePending
      case pending
      case agreed
    }
    public var jsonRepresentation: Foundation.Data {
      get { _abiUnimplemented("Product: public var jsonRepresentation: Foundation.Data {") }
    }
    public var originalTransactionID: Swift.UInt64 { _storeKitNoInstance() }
    public var currentProductID: Swift.String { _storeKitNoInstance() }
    public var willAutoRenew: Swift.Bool { _storeKitNoInstance() }
    public var autoRenewPreference: Swift.String? { _storeKitNoInstance() }
    public var expirationReason: Product.SubscriptionInfo.RenewalInfo.ExpirationReason? { _storeKitNoInstance() }
    public var priceIncreaseStatus: Product.SubscriptionInfo.RenewalInfo.PriceIncreaseStatus { _storeKitNoInstance() }
    public var isInBillingRetry: Swift.Bool { _storeKitNoInstance() }
    public var gracePeriodExpirationDate: Foundation.Date? { _storeKitNoInstance() }
    public var offerID: Swift.String? { _storeKitNoInstance() }
    public var offerType: Transaction.OfferType? { _storeKitNoInstance() }
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public var environment: AppStore.Environment { _storeKitNoInstance() }
    @available(iOS, introduced: 15.0, deprecated: 16.0, message: "Use the environment property instead")
    @available(macOS, introduced: 12.0, deprecated: 13.0, message: "Use the environment property instead")
    @available(tvOS, introduced: 15.0, deprecated: 16.0, message: "Use the environment property instead")
    @available(watchOS, introduced: 8.0, deprecated: 9.0, message: "Use the environment property instead")
    @available(macCatalyst, introduced: 15.0, deprecated: 16.0, message: "Use the environment property instead")
    public var environmentStringRepresentation: Swift.String { _storeKitNoInstance() }
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    @usableFromInline
    internal var recentSubscriptionStartDateStorage: Foundation.Date { _storeKitNoInstance() }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, macCatalyst 15.0, *)
    public var recentSubscriptionStartDate: Foundation.Date { _storeKitNoInstance() }
    public var deviceVerification: Foundation.Data { _storeKitNoInstance() }
    public var deviceVerificationNonce: Foundation.UUID { _storeKitNoInstance() }
    public var signedDate: Foundation.Date { _storeKitNoInstance() }
  }
  public struct Status : Swift.Equatable, Swift.Hashable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public var state: Product.SubscriptionInfo.RenewalState { _storeKitNoInstance() }
    public var transaction: VerificationResult<Transaction> { _storeKitNoInstance() }
    public var renewalInfo: VerificationResult<Product.SubscriptionInfo.RenewalInfo> { _storeKitNoInstance() }
    public static func == (a: Product.SubscriptionInfo.Status, b: Product.SubscriptionInfo.Status) -> Swift.Bool { _storeKitNoInstance() }
    public func hash(into hasher: inout Swift.Hasher) { _storeKitNoInstance() }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
  @inlinable public var status: [Product.SubscriptionInfo.Status] {
    get async throws {
            try await Product.SubscriptionInfo.status(for: subscriptionGroupID)
        }
  }
  public static func status(for groupID: Swift.String) async throws -> [Product.SubscriptionInfo.Status] { [] }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.Status {
  public struct Statuses : _Concurrency.AsyncSequence {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Element = Product.SubscriptionInfo.Status
    public struct AsyncIterator : _Concurrency.AsyncIteratorProtocol {
      @usableFromInline internal var _abiTag: Int = 0
      @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
      public mutating func next() async -> Product.SubscriptionInfo.Status.Statuses.Element? { nil }
      public typealias Element = Product.SubscriptionInfo.Status.Statuses.Element
    }
    public func makeAsyncIterator() -> Product.SubscriptionInfo.Status.Statuses.AsyncIterator { AsyncIterator(_abiTag: 0) }
  }
  public static var updates: Product.SubscriptionInfo.Status.Statuses {
    get { Product.SubscriptionInfo.Status.Statuses(_abiTag: 0) }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.RenewalInfo : Swift.Equatable {
  public static func == (lhs: Product.SubscriptionInfo.RenewalInfo, rhs: Product.SubscriptionInfo.RenewalInfo) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.RenewalInfo : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.RenewalInfo : Swift.CustomDebugStringConvertible {
  public var debugDescription: Swift.String { _storeKitNoInstance() }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.RenewalState : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.Status : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.Status.Statuses : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.RenewalInfo : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.RenewalInfo.ExpirationReason : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionInfo.RenewalInfo.PriceIncreaseStatus : Swift.Sendable {
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Product.PurchaseError : Foundation.LocalizedError {
  public var errorDescription: Swift.String? {
    get { "\(self)" }
  }
  public var failureReason: Swift.String? {
    get { nil }
  }
  public var recoverySuggestion: Swift.String? {
    get { nil }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Product.ProductType {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Product: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Product.SubscriptionInfo.RenewalState {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Product: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Product.SubscriptionInfo.RenewalInfo.ExpirationReason {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Product: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Product.SubscriptionInfo.RenewalInfo.PriceIncreaseStatus {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Product: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Product.SubscriptionOffer.OfferType {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Product: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Product.SubscriptionOffer.PaymentMode {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Product: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension Product.SubscriptionPeriod.Unit {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Product: public var localizedDescription: Swift.String {") }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product {
  public struct SubscriptionOffer : Swift.Equatable, Swift.Hashable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public struct OfferType : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable {
      public let rawValue: Swift.String
      public init(rawValue: Swift.String) { self.rawValue = rawValue }
      public static let introductory: Product.SubscriptionOffer.OfferType = Product.SubscriptionOffer.OfferType(rawValue: "introductory")
      public static let promotional: Product.SubscriptionOffer.OfferType = Product.SubscriptionOffer.OfferType(rawValue: "promotional")
      public typealias RawValue = Swift.String
    }
    public struct PaymentMode : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable {
      public let rawValue: Swift.String
      public init(rawValue: Swift.String) { self.rawValue = rawValue }
      public static let payAsYouGo: Product.SubscriptionOffer.PaymentMode = Product.SubscriptionOffer.PaymentMode(rawValue: "PayAsYouGo")
      public static let payUpFront: Product.SubscriptionOffer.PaymentMode = Product.SubscriptionOffer.PaymentMode(rawValue: "PayUpFront")
      public static let freeTrial: Product.SubscriptionOffer.PaymentMode = Product.SubscriptionOffer.PaymentMode(rawValue: "FreeTrial")
      public typealias RawValue = Swift.String
    }
    public var id: Swift.String? { _storeKitNoInstance() }
    public var type: Product.SubscriptionOffer.OfferType { _storeKitNoInstance() }
    public var price: Foundation.Decimal { _storeKitNoInstance() }
    public var displayPrice: Swift.String { _storeKitNoInstance() }
    public var period: Product.SubscriptionPeriod { _storeKitNoInstance() }
    public var periodCount: Swift.Int { _storeKitNoInstance() }
    public var paymentMode: Product.SubscriptionOffer.PaymentMode { _storeKitNoInstance() }
    public static func == (a: Product.SubscriptionOffer, b: Product.SubscriptionOffer) -> Swift.Bool { _storeKitNoInstance() }
    public func hash(into hasher: inout Swift.Hasher) { _storeKitNoInstance() }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionOffer : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionOffer.OfferType : Swift.Sendable {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.SubscriptionOffer.PaymentMode : Swift.Sendable {
}
@available(iOS 16.4, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Product.PromotionInfo.Visibility : Swift.RawRepresentable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.PurchaseError : Swift.Equatable {}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product.PurchaseError : Swift.Hashable {}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public enum AppStore {
  /// There is no App Store to pay: the same answer as +[SKPaymentQueue canMakePayments].
  public static var canMakePayments: Swift.Bool { false }
  public static var deviceVerificationID: Foundation.UUID? {
    get { UIDevice.current.identifierForVendor }
  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension AppStore.Environment {
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension AppStore {
  public static func sync() async throws { throw StoreKitError.notAvailableInStorefront }
}
@available(iOS 15.0, macCatalyst 15.0, *)
extension AppStore {
  @available(iOS 15.0, macCatalyst 15.0, *)
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  @_Concurrency.MainActor public static func showManageSubscriptions(in scene: UIKit.UIWindowScene) async throws { throw StoreKitError.notAvailableInStorefront }
}
extension AppStore {
  @available(iOS 16.0, macCatalyst 16.0, *)
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  @_Concurrency.MainActor public static func presentOfferCodeRedeemSheet(in scene: UIKit.UIWindowScene) async throws { throw StoreKitError.notAvailableInStorefront }
}
extension AppStore {
  @available(iOS 16.0, macCatalyst 16.0, *)
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  @_Concurrency.MainActor public static func requestReview(in scene: UIKit.UIWindowScene) {  }
}
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension AppStore {
  public struct Environment : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable, Swift.Sendable {
    public let rawValue: Swift.String
    public init(rawValue: Swift.String) { self.rawValue = rawValue }
    public static let production: AppStore.Environment = AppStore.Environment(rawValue: "Production")
    public static let sandbox: AppStore.Environment = AppStore.Environment(rawValue: "Sandbox")
    public static let xcode: AppStore.Environment = AppStore.Environment(rawValue: "Xcode")
    public typealias RawValue = Swift.String
  }
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension AppStore : Swift.Sendable {
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public enum StoreKitError : Swift.Error {
  case unknown
  case userCancelled
  case networkError(Foundation.URLError)
  case systemError(any Swift.Error)
  case notAvailableInStorefront
  @available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
  case notEntitled
}
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension StoreKitError : Swift.Sendable {
}
@available(iOS 15.4, macOS 12.3, tvOS 15.4, watchOS 8.5, *)
extension StoreKitError : Foundation.LocalizedError {
  public var errorDescription: Swift.String? {
    get {
      switch self {
      case .notAvailableInStorefront: return "The App Store is not available on this device."
      case .userCancelled: return "The request was cancelled."
      case .networkError(let error): return error.localizedDescription
      case .systemError(let error): return error.localizedDescription
      case .notEntitled: return "The app is not entitled to this request."
      case .unknown: return "An unknown error occurred."
      }
    }
  }
  public var failureReason: Swift.String? {
    get { nil }
  }
  public var recoverySuggestion: Swift.String? {
    get { nil }
  }
}

@available(iOS 16.4, macCatalyst 16.4, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct PurchaseIntent : Swift.Equatable, Swift.Sendable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public var product: Product { _storeKitNoInstance() }
  public var id: Product.ID {
    get { _abiUnimplemented("PurchaseIntent: public var id: Product.ID {") }
  }
  public static func == (a: PurchaseIntent, b: PurchaseIntent) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
}
@available(iOS 16.4, macCatalyst 16.4, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension PurchaseIntent {
  public struct PurchaseIntents : _Concurrency.AsyncSequence {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Element = PurchaseIntent
    public struct AsyncIterator : _Concurrency.AsyncIteratorProtocol {
      @usableFromInline internal var _abiTag: Int = 0
      @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
      public mutating func next() async -> PurchaseIntent.PurchaseIntents.Element? { nil }
      public typealias Element = PurchaseIntent.PurchaseIntents.Element
    }
    public func makeAsyncIterator() -> PurchaseIntent.PurchaseIntents.AsyncIterator { AsyncIterator(_abiTag: 0) }
  }
  public static var intents: PurchaseIntent.PurchaseIntents {
    get { PurchaseIntent.PurchaseIntents(_abiTag: 0) }
  }
}

@available(iOS 16.0, macCatalyst 16.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct Message : Swift.Sendable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  public var reason: Message.Reason { _storeKitNoInstance() }
  @available(iOS 16.0, macCatalyst 16.0, *)
  @available(macOS, unavailable)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public struct Reason : Swift.RawRepresentable, Swift.Equatable, Swift.Hashable, Swift.Sendable {
    public let rawValue: Swift.Int
    public init(rawValue: Swift.Int) { self.rawValue = rawValue }
    public static let generic: Message.Reason = Message.Reason(rawValue: 0)
    public static let priceIncreaseConsent: Message.Reason = Message.Reason(rawValue: 1)
    @available(iOS 16.4, macCatalyst 16.4, *)
    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public static let billingIssue: Message.Reason = Message.Reason(rawValue: 2)
    public typealias RawValue = Swift.Int
  }
}
@available(iOS 16.0, macCatalyst 16.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Message : Swift.Equatable {
  public static func == (lhs: Message, rhs: Message) -> Swift.Bool { String(describing: lhs) == String(describing: rhs) && _abiTagOf(lhs) == _abiTagOf(rhs) }
}
@available(iOS 16.0, macCatalyst 16.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Message : Swift.Hashable {
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 16.0, macCatalyst 16.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Message {
  @_Concurrency.MainActor public func display(in scene: UIKit.UIWindowScene) throws { _abiUnimplemented("Message: @_Concurrency.MainActor public func display(in scene: UIKit.UIWindowScene) throws") }
}
@available(iOS 16.0, macCatalyst 16.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Message {
  public struct Messages : _Concurrency.AsyncSequence, Swift.Sendable {
    @usableFromInline internal var _abiTag: Int = 0
    @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
    public typealias Element = Message
    public struct AsyncIterator : _Concurrency.AsyncIteratorProtocol {
      @usableFromInline internal var _abiTag: Int = 0
      @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
      public mutating func next() async -> Message.Messages.Element? { nil }
      public typealias Element = Message.Messages.Element
    }
    public func makeAsyncIterator() -> Message.Messages.AsyncIterator { AsyncIterator(_abiTag: 0) }
  }
  public static var messages: Message.Messages {
    get { Message.Messages(_abiTag: 0) }
  }
}
@available(iOS 16.0, macCatalyst 16.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension Message.Reason {
  public var localizedDescription: Swift.String {
    get { _abiUnimplemented("Message: public var localizedDescription: Swift.String {") }
  }
}

@available(iOS 15.4, macCatalyst 15.4, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public enum ExternalPurchaseLink {
  public static var canOpen: Swift.Bool {
    get async { false }
  }
  public static func open() async throws { throw StoreKitError.notAvailableInStorefront }
}
@available(iOS 15.4, macCatalyst 15.4, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension ExternalPurchaseLink : Swift.Sendable {
}

@available(iOS 16.0, macCatalyst 16.0, tvOS 16.4, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
public enum ExternalLinkAccount : Swift.Sendable {
  public static var canOpen: Swift.Bool {
    get async { false }
  }
  public static func open() async throws { throw StoreKitError.notAvailableInStorefront }
}

@available(iOS 15.4, macCatalyst 15.4, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public enum ExternalPurchase {
  public enum NoticeResult : Swift.Sendable {
    case continued
    case cancelled
    public static func == (a: ExternalPurchase.NoticeResult, b: ExternalPurchase.NoticeResult) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
  public static func presentNoticeSheet() async throws -> ExternalPurchase.NoticeResult { throw StoreKitError.notAvailableInStorefront }
}
@available(iOS 15.4, macCatalyst 15.4, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension ExternalPurchase : Swift.Sendable {
}
@available(iOS 15.4, macCatalyst 15.4, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension ExternalPurchase.NoticeResult : Swift.Equatable {}
@available(iOS 15.4, macCatalyst 15.4, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension ExternalPurchase.NoticeResult : Swift.Hashable {}

@available(iOS 16.4, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
public struct PaymentMethodBinding : Swift.Sendable, Swift.Hashable, Swift.Identifiable {
  @usableFromInline internal var _abiTag: Int = 0
  @usableFromInline internal init(_abiTag: Int) { self._abiTag = _abiTag }
  @available(iOS 16.4, *)
  @available(macOS, unavailable)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  public enum PaymentMethodBindingError : Foundation.LocalizedError {
    case notEligible
    case invalidPinningID
    case failed
    public var errorDescription: Swift.String? {
      get { "\(self)" }
    }
    public var failureReason: Swift.String? {
      get { nil }
    }
    public var recoverySuggestion: Swift.String? {
      get { nil }
    }
    public static func == (a: PaymentMethodBinding.PaymentMethodBindingError, b: PaymentMethodBinding.PaymentMethodBindingError) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
    public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
    public var hashValue: Swift.Int {
      get { var h = Hasher(); hash(into: &h); return h.finalize() }
    }
  }
  public var id: Swift.String { _storeKitNoInstance() }
  public init(id: Swift.String) async throws { throw StoreKitError.notAvailableInStorefront }
  public func bind() async throws { throw StoreKitError.notAvailableInStorefront }
  public func hash(into hasher: inout Swift.Hasher) { hasher.combine(String(describing: self)); hasher.combine(_abiTagOf(self)) }
  public static func == (a: PaymentMethodBinding, b: PaymentMethodBinding) -> Swift.Bool { String(describing: a) == String(describing: b) && _abiTagOf(a) == _abiTagOf(b) }
  public typealias ID = Swift.String
  public var hashValue: Swift.Int {
    get { var h = Hasher(); hash(into: &h); return h.finalize() }
  }
}
@available(iOS 16.4, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension PaymentMethodBinding.PaymentMethodBindingError : Swift.Equatable {}
@available(iOS 16.4, *)
@available(macOS, unavailable)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension PaymentMethodBinding.PaymentMethodBindingError : Swift.Hashable {}

