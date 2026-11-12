@usableFromInline func _abiUnimplemented(_ api: String, file: StaticString = #fileID, line: UInt = #line) -> Never {
    fatalError("StoreKit: \(api) is not implemented", file: file, line: line)
}
func _abiTagOf<T>(_ value: T) -> Int {
    Mirror(reflecting: value).children.first { $0.label == "_abiTag" }?.value as? Int ?? 0
}
/// Darling has no App Store: no product, transaction or renewal is ever handed out, so nothing can
/// ask one of them for a property.
func _storeKitNoInstance(file: StaticString = #fileID, line: UInt = #line) -> Never {
    fatalError("StoreKit: there is no App Store to have produced this value", file: file, line: line)
}
